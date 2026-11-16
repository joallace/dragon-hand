extends Node
## Autoload "Music": plays songs written in Strudel code (https://strudel.cc)
## on Tuning.music.bus. Presentation only; never read by the sim.
##
## Tracks (Tuning.music.tracks) are text files in res://data/music/; the
## track for the current scene (Tuning.music.scene_tracks: menus, match)
## starts by itself. A file with the same name in Tuning.music.user_dir
## (user://music/menu.strudel, .../match.strudel) replaces the built-in one.
##
##   Music.play_track(&"match")
##   Music.play_file("res://data/music/demo.strudel")
##   Music.play(code)      # e.g. text the player typed; errors -> song_failed
##   Music.stop()
##
## A song replaces the current one on the beat grid (after about
## Tuning.music.lookahead seconds) unless `from_start` is set. A song that
## fails to evaluate leaves the current one playing. Engines: MusicEngine
## (desktop extension or browser); where there is none available() is false
## and every call does nothing.

## The song is now the one playing. `warnings` lists what it uses that the
## synth doesn't have (e.g. sample names).
signal song_started(warnings: PackedStringArray)
signal song_failed(error: String)

const SONG_EXTENSION := ".strudel"

## Start the scene's track on scene changes. Off headless (tests and tools
## would all start a music thread); tests may turn it on.
var auto_play := DisplayServer.get_name() != "headless"
## The track asked for last ("" after stop() or a plain play()).
var current_track: StringName = &""

## Built-in file to fall back to if the user's replacement fails to load.
var _fallback_path := ""
var _engine: MusicEngine
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
	_engine = MusicEngine.create(rate)
	_engine.song_loaded.connect(_on_song_loaded)
	_engine.start()
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func _exit_tree() -> void:
	if _engine != null:
		_playback = null
		_player.stop()
		_engine.stop()


static func available() -> bool:
	return Tuning.music.enabled and MusicEngine.backend_available()


## The built-in file of a track ("" for an unknown track).
static func track_path(track: StringName) -> String:
	return Tuning.music.tracks.get(track, "")


## Where a replacement for `track` goes.
static func user_track_path(track: StringName) -> String:
	return Tuning.music.user_dir.path_join(String(track) + SONG_EXTENSION)


## Plays a named track from its start: the user's replacement if there is
## one, else the built-in file. Asking for the track already playing does
## nothing, so it carries on across screens.
func play_track(track: StringName) -> void:
	if _engine == null or (track == current_track and is_playing()):
		return
	var built_in := track_path(track)
	if built_in.is_empty():
		song_failed.emit("no such track: " + String(track))
		return
	var user := user_track_path(track)
	var use_user := FileAccess.file_exists(user)
	print_verbose("Music: track %s from %s" % [track, user if use_user else built_in])
	play_file(user if use_user else built_in, true)
	current_track = track
	_fallback_path = built_in if use_user else ""


func play(code: String, from_start: bool = false) -> void:
	if _engine == null:
		return
	current_track = &""
	_fallback_path = ""
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
	current_track = &""
	_fallback_path = ""
	_engine.halt()
	_player.stop()
	_playback = null
	set_process(false)


func is_playing() -> bool:
	return _player != null and _player.playing


## Seconds of music rendered into the audio stream so far (the synth clock;
## restarts at 0 with a song started from the beginning). It only advances
## while the audio output is actually pulling frames.
func playback_time() -> float:
	return _engine.synth_time() if _engine != null else 0.0


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames > 0:
		_playback.push_buffer(_engine.render(frames))


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or not auto_play or not Tuning.music.auto_play:
		return
	for prefix: String in Tuning.music.scene_tracks:
		if scene.scene_file_path.begins_with(prefix):
			play_track(Tuning.music.scene_tracks[prefix])
			return


func _on_song_loaded(ok: bool, message: String) -> void:
	if ok:
		_fallback_path = ""
		song_started.emit(message.split("\n", false))
		return
	song_failed.emit(message)
	if not _fallback_path.is_empty():
		# The user's replacement track is broken: play the built-in one.
		var track := current_track
		var path := _fallback_path
		push_warning("Music: %s failed (%s); playing the built-in track" % [user_track_path(track), message])
		play_file(path, true)
		current_track = track
