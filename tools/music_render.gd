extends Node
## Renders a Strudel song to a WAV file, offline (faster than real time), to
## listen to a song or to the synth without running the game:
##   godot --headless res://tools/music_render.tscn -- \
##       song=res://data/music/demo.strudel seconds=30 out=/tmp/demo.wav [rate=44100]
## Prints MUSIC_RENDER lines (peak, RMS, voices, render speed); exit 1 on error.
## `live=1` plays the song through the Music autoload instead (the real-time
## path the game uses; run without --headless to hear it) for `seconds`.

const DEFAULT_SECONDS := 20.0
const DEFAULT_RATE := 44100
const PCM_SCALE := 32767.0

var _error := ""
var _warnings := ""


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var song: String = args.get("song", "res://data/music/demo.strudel")
	var seconds := float(args.get("seconds", DEFAULT_SECONDS))
	var rate := int(args.get("rate", DEFAULT_RATE))
	var out: String = args.get("out", "")
	if not StrudelEngine.available() or not FileAccess.file_exists(song):
		_fail("engine unavailable or song not found: " + song)
		return

	if args.get("live", "0") == "1":
		Music.song_started.connect(func(warnings: PackedStringArray) -> void:
			print("MUSIC_RENDER live: playing, warnings=", warnings))
		Music.song_failed.connect(func(error: String) -> void: print("MUSIC_RENDER error: ", error))
		Music.play_file(song)
		await get_tree().create_timer(seconds).timeout
		Music.stop()
		get_tree().quit(0)
		return

	var engine := StrudelEngine.new(rate)
	engine.song_loaded.connect(func(ok: bool, message: String) -> void:
		if ok:
			_warnings = message
		else:
			_error = message)
	engine.start(false)
	engine.load_song(FileAccess.get_file_as_string(song))
	engine.pump()
	await get_tree().process_frame
	if not _error.is_empty():
		_fail(_error)
		return
	for line in _warnings.split("\n", false):
		print("MUSIC_RENDER warning: ", line)

	# Each pass schedules `lookahead` ahead, so render less than that per pass.
	var chunk := int(rate * Tuning.music.lookahead * 0.5)
	var total := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(total * 4)
	var peak := 0.0
	var sum := 0.0
	var max_voices := 0
	var start := Time.get_ticks_usec()
	var done := 0
	while done < total:
		engine.pump()
		var frames := engine.render(mini(chunk, total - done))
		max_voices = maxi(max_voices, engine.active_voices())
		for i in frames.size():
			var f := frames[i]
			peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
			sum += f.x * f.x + f.y * f.y
			data.encode_s16((done + i) * 4, int(clampf(f.x, -1.0, 1.0) * PCM_SCALE))
			data.encode_s16((done + i) * 4 + 2, int(clampf(f.y, -1.0, 1.0) * PCM_SCALE))
		done += frames.size()
	var elapsed := float(Time.get_ticks_usec() - start) / 1e6
	print("MUSIC_RENDER seconds=%.1f rate=%d peak=%.3f rms=%.3f max_voices=%d speed=%.1fx realtime" % [
			seconds, rate, peak, sqrt(sum / maxf(total * 2.0, 1.0)), max_voices, seconds / maxf(elapsed, 1e-6)])
	if not out.is_empty():
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.stereo = true
		wav.mix_rate = rate
		wav.data = data
		var err := wav.save_to_wav(out)
		print("MUSIC_RENDER wrote %s (%s)" % [out, error_string(err)])
	get_tree().quit(0)


func _fail(message: String) -> void:
	print("MUSIC_RENDER error: ", message)
	get_tree().quit(1)
