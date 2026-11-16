class_name StrudelEngine
extends MusicEngine
## The desktop music engine. Plays Strudel code: Strudel's own pattern engine
## (strudel_bundle.mjs, run by the JsRuntime extension) feeds note events to
## StrudelSynth, a few hundred ms ahead of the audio that render() hands out.
##
## Everything JavaScript runs on a worker thread (evaluating a song or
## querying a cycle takes milliseconds); the owner only calls render().
## Without the extension library available() is false (the browser has
## WebMusicEngine instead).
##
## Song changes keep the cycle position, so a new section comes in on the
## grid; restart() rewinds to cycle 0.
##
## Song code is untrusted (players may type it). Every song gets its own
## fresh JsRuntime, swapped in only if the song loads, so a song that fails,
## times out or tampers with the host cannot affect the one playing or the
## next; the tempo it asks for is clamped; one scheduling pass is bounded.

## Strudel's pattern engine + the host glue, built by native/strudel/js.
const BUNDLE := "res://presentation/audio/music/strudel_bundle.mjs"
const BUNDLE_MODULE := "music/bundle.mjs"
const BOOT := "import '%s';" % BUNDLE_MODULE
## Finest query slice (a power of two), reached only at the slowest tempos.
const MAX_STEPS_PER_CYCLE := 1 << 16

var _js: RefCounted  # JsRuntime
var _synth: RefCounted  # StrudelSynth
var _fields := 0
var _thread: Thread
var _lock := Mutex.new()  # guards the fields below
var _running := false
var _pending_song := ""
var _has_pending := false
var _restart := false
var _playing := false
# Worker-only state.
var _cps := 1.0
var _cycle := 0.0  # scheduled through this cycle (a dyadic fraction, so sums stay exact)
var _scheduled_until := 0.0  # synth seconds


static func available() -> bool:
	return ClassDB.class_exists(&"JsRuntime") and ClassDB.class_exists(&"StrudelSynth")


func _init(sample_rate: float) -> void:
	if not available():
		return
	_synth = ClassDB.instantiate(&"StrudelSynth")
	_synth.setup(sample_rate)
	_synth.set_master_gain(Tuning.music.master_gain)
	_fields = _synth.get_event_fields()


## Starts the worker thread; `threaded = false` is for tests and offline
## rendering, which drive it with pump().
func start(threaded: bool = true) -> void:
	if _synth == null or _running:
		return
	_running = true
	if threaded:
		_thread = Thread.new()
		_thread.start(_worker)


func stop() -> void:
	_lock.lock()
	_running = false
	_lock.unlock()
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


## Queues `code` to replace the current song; song_loaded reports the result.
func load_song(code: String) -> void:
	_lock.lock()
	_pending_song = code
	_has_pending = true
	_lock.unlock()


## Silence, and the next song starts from cycle 0.
func restart() -> void:
	_lock.lock()
	_restart = true
	_lock.unlock()


## restart(), and a song still waiting to be loaded is dropped.
func halt() -> void:
	_lock.lock()
	_restart = true
	_has_pending = false
	_pending_song = ""
	_lock.unlock()


## Stereo frames at the sample rate given to _init (silence when unavailable).
func render(frames: int) -> PackedVector2Array:
	if _synth == null:
		var silence := PackedVector2Array()
		silence.resize(maxi(frames, 0))
		return silence
	return _synth.render(frames)


func synth_time() -> float:
	return _synth.get_time() if _synth != null else 0.0


func active_voices() -> int:
	return _synth.get_active_voices() if _synth != null else 0


## One scheduling pass: pending commands, then events up to the lookahead.
## The worker thread loops on this; unthreaded owners call it themselves.
func pump() -> void:
	if _synth == null:
		return
	_lock.lock()
	var song := _pending_song
	var has_song := _has_pending
	var rewind := _restart
	_has_pending = false
	_pending_song = ""
	_restart = false
	_lock.unlock()

	if rewind:
		_synth.reset()
		_cycle = 0.0
		_scheduled_until = 0.0
		_playing = false
	if has_song:
		_load(song)
	if _playing:
		_schedule_ahead()


func _worker() -> void:
	while true:
		_lock.lock()
		var keep_going := _running
		_lock.unlock()
		if not keep_going:
			break
		pump()
		OS.delay_msec(Tuning.music.worker_idle_msec)


func _is_running() -> bool:
	_lock.lock()
	var running := _running
	_lock.unlock()
	return running


## A booted runtime, or null with `error[0]` set.
func _new_runtime(error: Array[String]) -> RefCounted:
	var js: RefCounted = ClassDB.instantiate(&"JsRuntime")
	js.set_memory_limit(Tuning.music.memory_limit_bytes)
	js.set_time_limit_msec(Tuning.music.load_time_limit_msec)
	js.add_module(BUNDLE_MODULE, FileAccess.get_file_as_string(BUNDLE))
	if not js.run_module(BOOT, "music/boot.mjs"):
		error.append("music engine failed to start: " + js.get_error())
		return null
	if js.call_global("music_fields", []) != _fields:
		error.append("music host and synth disagree on the event layout")
		return null
	return js


func _load(code: String) -> void:
	if code.to_utf8_buffer().size() > Tuning.music.max_song_bytes:
		_report(false, "song is larger than %d bytes" % Tuning.music.max_song_bytes)
		return
	var error: Array[String] = []
	var js := _new_runtime(error)
	if js == null:
		_report(false, error[0])
		return
	js.set_time_limit_msec(Tuning.music.load_time_limit_msec)
	var result: Variant = js.call_global("music_load", [code])
	if js.has_error() or not result is Dictionary:
		# `js` is dropped; the current song and its runtime are untouched.
		_report(false, js.get_error().get_slice("\n", 0))
		return
	var info: Dictionary = result
	var cps: Variant = info.get("cps")
	_cps = Tuning.music.default_cps
	if (cps is float or cps is int) and is_finite(cps) and cps > 0.0:
		_cps = clampf(cps, Tuning.music.min_cps, Tuning.music.max_cps)
	_js = js
	_playing = true
	var warnings := PackedStringArray()
	for warning: Variant in info.get("warnings", []):
		warnings.append(str(warning))
	_report(true, "\n".join(warnings))


func _schedule_ahead() -> void:
	var target: float = _synth.get_time() + Tuning.music.lookahead
	# After a stall (or the first song), don't burst through the missed time.
	_scheduled_until = maxf(_scheduled_until, _synth.get_time())
	# Slices are halved (boundaries stay exact floats) until one lasts at
	# most half the lookahead, so even a very slow song is queued only a
	# moment ahead and a song change is heard within the lookahead.
	var steps := maxi(Tuning.music.query_steps_per_cycle, 1)
	while 1.0 / (steps * _cps) > Tuning.music.lookahead * 0.5 and steps < MAX_STEPS_PER_CYCLE:
		steps *= 2
	var slice := 1.0 / steps
	_js.set_time_limit_msec(Tuning.music.query_time_limit_msec)
	var passes := 0
	# Bounded: a fast tempo takes several pumps to catch up instead of
	# holding the thread (and stop() waiting on it).
	while _scheduled_until < target and passes < Tuning.music.max_steps_per_pump and _is_running():
		var records: Variant = _js.call_global("music_query", [_cycle, _cycle + slice, _scheduled_until, _cps])
		if not _js.has_error() and records is Array and (records as Array).size() % _fields == 0 \
				and not (records as Array).is_empty():
			_synth.schedule(PackedFloat64Array(records as Array))
		_cycle += slice
		_scheduled_until += slice / _cps
		passes += 1


func _report(ok: bool, message: String) -> void:
	song_loaded.emit.call_deferred(ok, message)
