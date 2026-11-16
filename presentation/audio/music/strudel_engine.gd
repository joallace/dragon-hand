class_name StrudelEngine
extends RefCounted
## Plays Strudel code: Strudel's own pattern engine (strudel_bundle.mjs, run
## by the JsRuntime extension) feeds note events to StrudelSynth, a few
## hundred ms ahead of the audio that render() hands out.
##
## Everything JavaScript runs on a worker thread (evaluating a song or
## querying a cycle takes milliseconds); the owner only calls render().
## Without the extension library (web for now) available() is false.
##
## Song changes keep the cycle position, so a new section comes in on the
## grid; restart() rewinds to cycle 0.

## (ok, message): message is the error, or warnings joined by newlines.
signal song_loaded(ok: bool, message: String)

## Strudel's pattern engine + the host glue, built by native/strudel/js.
const BUNDLE := "res://presentation/audio/music/strudel_bundle.mjs"
const BUNDLE_MODULE := "music/bundle.mjs"
const BOOT := "import '%s';" % BUNDLE_MODULE

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
var _cps := 0.5
var _step := 0  # scheduled through cycle _step / query_steps_per_cycle
var _scheduled_until := 0.0  # synth seconds
var _booted := false


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
		_step = 0
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


func _boot() -> String:
	_js = ClassDB.instantiate(&"JsRuntime")
	_js.set_memory_limit(Tuning.music.memory_limit_bytes)
	_js.set_time_limit_msec(Tuning.music.load_time_limit_msec)
	_js.add_module(BUNDLE_MODULE, FileAccess.get_file_as_string(BUNDLE))
	if not _js.run_module(BOOT, "music/boot.mjs"):
		return "music engine failed to start: " + _js.get_error()
	if int(_js.call_global("music_fields", [])) != _fields:
		return "music host and synth disagree on the event layout"
	_booted = true
	return ""


func _load(code: String) -> void:
	var error := ""
	if not _booted:
		error = _boot()
	if error.is_empty() and code.to_utf8_buffer().size() > Tuning.music.max_song_bytes:
		error = "song is larger than %d bytes" % Tuning.music.max_song_bytes
	if not error.is_empty():
		_report(false, error)
		return
	_js.set_time_limit_msec(Tuning.music.load_time_limit_msec)
	var result: Variant = _js.call_global("music_load", [code])
	if _js.has_error() or not result is Dictionary:
		# The host keeps the previous song, so playback carries on.
		_report(false, _js.get_error().get_slice("\n", 0))
		return
	var info: Dictionary = result
	_cps = maxf(float(info.get("cps", _cps)), 0.001)
	_playing = true
	_report(true, "\n".join(PackedStringArray(info.get("warnings", []))))


func _schedule_ahead() -> void:
	var steps := maxi(Tuning.music.query_steps_per_cycle, 1)
	var target: float = _synth.get_time() + Tuning.music.lookahead
	# After a stall (or the first song), don't burst through the missed time.
	_scheduled_until = maxf(_scheduled_until, _synth.get_time())
	_js.set_time_limit_msec(Tuning.music.query_time_limit_msec)
	while _scheduled_until < target:
		var begin := float(_step) / steps
		var end := float(_step + 1) / steps
		var records: Variant = _js.call_global("music_query", [begin, end, _scheduled_until])
		if records is Array and not (records as Array).is_empty():
			_synth.schedule(PackedFloat64Array(records as Array))
		_step += 1
		_scheduled_until += 1.0 / (steps * _cps)


func _report(ok: bool, message: String) -> void:
	song_loaded.emit.call_deferred(ok, message)
