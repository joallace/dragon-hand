class_name WebMusicEngine
extends MusicEngine
## The music engine in a browser. music_web.js (evaluated in the page) does
## the work: every song runs Strudel's pattern engine (strudel_bundle.mjs)
## in its own Web Worker, so a song that hangs is terminated instead of
## freezing the page; events are queued ahead into the synth, which is
## synth.c compiled to WebAssembly (synth.wasm) running in an AudioWorklet,
## on the browser's audio thread. All three files are read from the game's
## pack and handed to the page, so the export needs no extra files.
##
## The sound goes straight to the page's audio output (plays_itself()), not
## through Godot's mixer: the single-threaded web build mixes on the main
## thread, and a stream fed from there breaks up when frames are slow (mobile
## Chrome). So bus volumes don't reach it: the owner passes the volume with
## set_output_gain(), and render() only gives silence.
##
## Scheduling and song results run once per game frame (SceneTree
## process_frame, from start() on) whether or not audio is running: the
## page's audio is suspended until the player first clicks or presses a key,
## but a song still loads and reports.

const GLUE := "res://presentation/audio/music/music_web.js"
const SYNTH_WASM := "res://presentation/audio/music/synth.wasm"
const HOST := "GHMusic"

## The page's engine table (null where it could not be set up).
var _host: JavaScriptObject
var _id := 0
var _ticking := false
var _time := 0.0
var _voices := 0
var _running := false
var _gain := 1.0
## Output level since the last take_output_stats().
var _peak := 0.0
var _sum := 0.0
var _frames := 0
var _finite := true


static func available() -> bool:
	return OS.has_feature("web") and FileAccess.file_exists(GLUE) and FileAccess.file_exists(SYNTH_WASM) \
			and FileAccess.file_exists(StrudelEngine.BUNDLE)


func _init(sample_rate: float) -> void:
	if not available():
		return
	JavaScriptBridge.eval(FileAccess.get_file_as_string(GLUE), true)
	_host = JavaScriptBridge.get_interface(HOST)
	if _host == null:
		return
	var t := Tuning.music
	var config := {
		"sample_rate": sample_rate,
		"master_gain": t.master_gain,
		"lookahead": t.lookahead,
		"query_steps_per_cycle": t.query_steps_per_cycle,
		"max_steps_per_cycle": StrudelEngine.MAX_STEPS_PER_CYCLE,
		"max_steps_per_pump": t.max_steps_per_pump,
		"default_cps": t.default_cps,
		"min_cps": t.min_cps,
		"max_cps": t.max_cps,
		"load_time_limit_msec": t.load_time_limit_msec,
		"boot_time_limit_msec": t.web_boot_time_limit_msec,
		"spare_delay_msec": t.web_spare_worker_delay_msec,
		"reply_timeout_frames": t.web_reply_timeout_frames,
	}
	_id = int(_host.create(FileAccess.get_file_as_string(StrudelEngine.BUNDLE),
			Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(SYNTH_WASM)), JSON.stringify(config)))
	if _id <= 0:
		_host = null


## Ticks once per game frame until stop(). `threaded` has no meaning here:
## the page's workers do the background work either way.
func start(_threaded: bool = true) -> void:
	if _host == null or _ticking:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.process_frame.connect(pump)
	_ticking = true


## Stops ticking and frees the engine in the page (songs, workers, synth).
func stop() -> void:
	if _ticking:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.process_frame.is_connected(pump):
			tree.process_frame.disconnect(pump)
		_ticking = false
	if _host != null:
		_host.destroy(_id)
		_host = null


func load_song(code: String) -> void:
	if _host == null:
		return
	if code.to_utf8_buffer().size() > Tuning.music.max_song_bytes:
		song_loaded.emit.call_deferred(false, "song is larger than %d bytes" % Tuning.music.max_song_bytes)
		return
	_host.load(_id, code)


func restart() -> void:
	if _host != null:
		_host.restart(_id)


func halt() -> void:
	if _host != null:
		_host.halt(_id)


## One scheduling pass, then the song results and synth clock since the last.
func pump() -> void:
	if _host == null:
		return
	var text: Variant = _host.tick(_id)
	if not text is String or (text as String).is_empty():
		return
	var state: Variant = JSON.parse_string(text)
	if not state is Dictionary:
		return
	_time = float((state as Dictionary).get("time", _time))
	_voices = int((state as Dictionary).get("voices", _voices))
	_running = bool((state as Dictionary).get("running", false))
	var peak := float((state as Dictionary).get("peak", 0.0))
	var sum := float((state as Dictionary).get("sum", 0.0))
	_finite = _finite and peak >= 0.0 and sum >= 0.0
	_peak = maxf(_peak, peak)
	_sum += sum
	_frames += int((state as Dictionary).get("frames", 0))
	for result: Variant in (state as Dictionary).get("results", []):
		if not result is Dictionary:
			continue
		if bool(result.get("loaded", true)):
			song_loaded.emit(bool(result.get("ok", false)), str(result.get("message", "")))
		else:
			push_warning("Music: " + str(result.get("message", "")))


func plays_itself() -> bool:
	return true


func set_output_gain(linear: float) -> void:
	if _host != null and not is_equal_approx(linear, _gain):
		_gain = linear
		_host.gain(_id, linear)


func output_running() -> bool:
	return _running


func take_output_stats() -> Dictionary:
	var stats := {"peak": _peak, "sum": _sum, "frames": _frames, "finite": _finite}
	_peak = 0.0
	_sum = 0.0
	_frames = 0
	_finite = true
	return stats


func synth_time() -> float:
	return _time


func active_voices() -> int:
	return _voices
