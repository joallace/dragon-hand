extends Node
## End-to-end check of the platform's music engine, in real time, the way
## the Music autoload drives it (one render per frame). Runs on desktop and,
## through the "Web Tools" export, in a browser:
##   godot --headless res://tools/music_check.tscn [-- seconds=4]
##   tools/web_tools.sh tool=music
## Prints MUSIC_CHECK lines and ends with `MUSIC_CHECK DONE OK|FAIL`.
## It measures the rendered signal; it cannot tell how it sounds.

const DEFAULT_SECONDS := 4.0
const LOAD_TIMEOUT_SEC := 30.0
const AUDIBLE_RMS := 0.02
const SILENT_PEAK := 1e-3
## After a swap to a silent song, the old song's delay/reverb tails still
## decay for a while: "replaced" means this much quieter than it was.
const REPLACED_PEAK := 0.05
const FRAME_RATE := 60.0
## How long the autoload's stream is watched for the audio output pulling it.
const OUTPUT_WAIT_SEC := 2.0

var _engine: MusicEngine
var _rate := 44100.0
var _results: Array = []  # [ok, message]
var _failed := false


func _ready() -> void:
	var seconds := DEFAULT_SECONDS
	for arg in ToolArgs.pairs():
		var kv := arg.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "seconds":
			seconds = float(kv[1])
	_rate = AudioServer.get_mix_rate()
	_engine = MusicEngine.create(_rate)
	print("MUSIC_CHECK start %s rate=%d engine=%s" % [OS.get_name(), _rate,
			"none" if _engine == null else (_engine.get_script() as Script).get_global_name()])
	if _engine == null:
		_done(false)
		return
	_engine.song_loaded.connect(func(ok: bool, message: String) -> void: _results.append([ok, message]))
	_engine.start()

	var match_song := FileAccess.get_file_as_string(Music.track_path(&"match"))
	var loaded: Array = await _load(match_song)
	_check(loaded[0] and loaded[1] == "", "match track loads (%.0f ms) %s" % [loaded[2], loaded.slice(0, 2)])
	var stats: Dictionary = await _play(seconds)
	_check(stats.finite and stats.rms > AUDIBLE_RMS and stats.peak <= 1.0,
			"match track sounds: rms %.3f peak %.3f, slowest render %.2f ms" % [stats.rms, stats.peak, stats.slowest_ms])

	loaded = await _load("note(\"c3\"")
	_check(not loaded[0], "a song with a syntax error is refused: %s" % loaded[1])
	stats = await _play(1.0)
	_check(stats.rms > AUDIBLE_RMS, "the match track keeps playing after it (rms %.3f)" % stats.rms)

	loaded = await _load("const never = (() => { for (;;) {} })()\n$: s(\"bd\")")
	_check(not loaded[0], "a song that never finishes is stopped after %.0f ms: %s" % [loaded[2], loaded[1]])
	stats = await _play(1.0)
	_check(stats.rms > AUDIBLE_RMS, "and the match track is still playing (rms %.3f)" % stats.rms)

	# A silent song: the level drops only if it really took over.
	loaded = await _load("$: note(\"c3\").gain(0)")
	_check(loaded[0], "a silent song loads %s" % [loaded.slice(0, 2)])
	await _play(1.0)  # what was already queued ahead plays out
	stats = await _play(1.0)
	_check(stats.peak < REPLACED_PEAK, "and replaces the match track (peak %.5f)" % stats.peak)

	if OS.has_feature("web"):
		# A song that loads, then crashes while playing (a worker error):
		# the playing song stops, but that is not a failed load.
		loaded = await _load("setTimeout(() => { throw new Error('late') }, 300)\n$: s(\"bd*2\")")
		_check(loaded[0], "a song that crashes later loads %s" % [loaded.slice(0, 2)])
		await _play(1.0)
		_check(_results.size() == 1, "and its crash is not reported as a load %s" % [_results])

	loaded = await _load("setcpm(120)\n$: s(\"bd*2\")\n$: n(\"0 4 7\").scale(\"A:minor\").s(\"sawtooth\").lpf(900)")
	_check(loaded[0] and loaded[1] == "", "a second song replaces it %s" % [loaded.slice(0, 2)])
	stats = await _play(2.0)
	_check(stats.finite and stats.rms > AUDIBLE_RMS, "and sounds (rms %.3f)" % stats.rms)

	_engine.halt()
	await _play(0.5)
	stats = await _play(0.5)
	_check(stats.peak < SILENT_PEAK, "halt() silences (peak %.5f)" % stats.peak)

	# The autoload, on the same engine kind (on web they share the page's host).
	_results.clear()
	Music.song_started.connect(func(warnings: PackedStringArray) -> void: _results.append([true, "\n".join(warnings)]))
	Music.song_failed.connect(func(error: String) -> void: _results.append([false, error]))
	Music.play_track(&"menu")
	var deadline := Time.get_ticks_msec() + int(LOAD_TIMEOUT_SEC * 1000.0)
	while _results.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not _results.is_empty() and _results[0][0] and Music.is_playing(), "Music.play_track(menu) starts %s" % [_results])
	# The audio output pulls the autoload's stream: its synth clock moves.
	var before := Music.playback_time()
	deadline = Time.get_ticks_msec() + int(OUTPUT_WAIT_SEC * 1000.0)
	while Music.playback_time() - before < OUTPUT_WAIT_SEC * 0.5 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(Music.playback_time() - before >= OUTPUT_WAIT_SEC * 0.5,
			"the audio output plays it (%.2f s rendered in %.0f s)" % [Music.playback_time() - before, OUTPUT_WAIT_SEC])
	Music.stop()
	_engine.stop()
	_done(not _failed)


func _check(ok: bool, what: String) -> void:
	_failed = _failed or not ok
	print("MUSIC_CHECK %s %s" % ["PASS" if ok else "FAIL", what])


func _done(ok: bool) -> void:
	print("MUSIC_CHECK DONE %s" % ("OK" if ok else "FAIL"))
	if not OS.has_feature("web"):
		get_tree().quit(0 if ok else 1)


## [ok, message, msec]: renders frame by frame until song_loaded arrives.
func _load(code: String) -> Array:
	_results.clear()
	var start := Time.get_ticks_msec()
	_engine.load_song(code)
	while _results.is_empty() and Time.get_ticks_msec() - start < LOAD_TIMEOUT_SEC * 1000.0:
		_engine.render(int(_rate / FRAME_RATE))
		await get_tree().process_frame
	var elapsed := float(Time.get_ticks_msec() - start)
	if _results.is_empty():
		return [false, "no song_loaded within %.0f s" % LOAD_TIMEOUT_SEC, elapsed]
	return [_results[0][0], _results[0][1], elapsed]


## Renders `seconds` of audio, one frame's worth per frame.
func _play(seconds: float) -> Dictionary:
	var per_frame := int(_rate / FRAME_RATE)
	var total := int(seconds * _rate)
	var done := 0
	var peak := 0.0
	var sum := 0.0
	var finite := true
	var slowest := 0
	while done < total:
		var start := Time.get_ticks_usec()
		var frames := _engine.render(per_frame)
		slowest = maxi(slowest, Time.get_ticks_usec() - start)
		for f in frames:
			finite = finite and is_finite(f.x) and is_finite(f.y)
			peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
			sum += f.x * f.x + f.y * f.y
		done += frames.size()
		await get_tree().process_frame
	return {"peak": peak, "rms": sqrt(sum / maxf(done * 2.0, 1.0)), "finite": finite, "slowest_ms": slowest / 1000.0}
