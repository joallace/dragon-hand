extends Node
## Autoload "Music": plays songs written in Strudel code (https://strudel.cc)
## on Tuning.music.bus. Presentation only; never read by the sim.
##
##   Music.play_file("res://data/music/demo.strudel")
##   Music.play(code)      # e.g. text the player typed; errors -> song_failed
##   Music.stop()
##
## A song replaces the current one on the beat grid (after about
## Tuning.music.lookahead seconds) unless `from_start` is set. A song that
## fails to evaluate leaves the current one playing. Does nothing where the
## engine is unavailable (available() is false: web for now).

## The song is now the one playing. `warnings` lists what it uses that the
## synth doesn't have (e.g. sample names).
signal song_started(warnings: PackedStringArray)
signal song_failed(error: String)

var _engine: StrudelEngine
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if not available():
		return
	var rate := AudioServer.get_mix_rate()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = rate
	stream.buffer_length = Tuning.music.buffer_length
	_player = AudioStreamPlayer.new()
	_player.name = "Player"
	_player.stream = stream
	_player.bus = Tuning.music.bus
	_player.volume_db = Tuning.music.volume_db
	add_child(_player)
	_engine = StrudelEngine.new(rate)
	_engine.song_loaded.connect(_on_song_loaded)
	_engine.start()


func _exit_tree() -> void:
	if _engine != null:
		_playback = null
		_player.stop()
		_engine.stop()


static func available() -> bool:
	return Tuning.music.enabled and StrudelEngine.available()


func play(code: String, from_start: bool = false) -> void:
	if _engine == null:
		return
	if from_start:
		_engine.restart()
	_engine.load_song(code)
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
		set_process(true)


func play_file(path: String, from_start: bool = false) -> void:
	if not FileAccess.file_exists(path):
		song_failed.emit("no such song: " + path)
		return
	play(FileAccess.get_file_as_string(path), from_start)


func stop() -> void:
	if _engine == null:
		return
	_engine.restart()
	_player.stop()
	_playback = null
	set_process(false)


func is_playing() -> bool:
	return _player != null and _player.playing


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames > 0:
		_playback.push_buffer(_engine.render(frames))


func _on_song_loaded(ok: bool, message: String) -> void:
	if ok:
		song_started.emit(message.split("\n", false))
	else:
		song_failed.emit(message)
