class_name MusicEngine
extends RefCounted
## What the Music autoload drives: something that takes Strudel code and
## hands out stereo frames. StrudelEngine (desktop: JsRuntime + StrudelSynth
## extension) and WebMusicEngine (browser: a Web Worker per song + the synth
## as WebAssembly in an AudioWorklet, which plays by itself instead of being
## pulled with render()) implement it with the same behaviour: songs load in the
## background, a song that fails leaves the current one playing, song
## changes keep the cycle position, restart() rewinds to cycle 0.

## (ok, message): message is the error, or warnings joined by newlines.
@warning_ignore("unused_signal")
signal song_loaded(ok: bool, message: String)


## The engine for this platform, or null where there is none.
static func create(sample_rate: float) -> MusicEngine:
	if StrudelEngine.available():
		return StrudelEngine.new(sample_rate)
	if WebMusicEngine.available():
		return WebMusicEngine.new(sample_rate)
	return null


static func backend_available() -> bool:
	return StrudelEngine.available() or WebMusicEngine.available()


## Starts background work. `threaded = false` (desktop tests and offline
## rendering) leaves scheduling to the caller's pump().
func start(_threaded: bool = true) -> void:
	pass


func stop() -> void:
	pass


## Queues `code` to replace the current song; song_loaded reports the result.
func load_song(_code: String) -> void:
	pass


## Silence, and the next song starts from cycle 0.
func restart() -> void:
	pass


## restart(), and a song still waiting to be loaded is dropped.
func halt() -> void:
	pass


## One scheduling pass, for owners that run the engine unthreaded.
func pump() -> void:
	pass


## Stereo frames at the sample rate given at creation.
func render(frames: int) -> PackedVector2Array:
	var silence := PackedVector2Array()
	silence.resize(maxi(frames, 0))
	return silence


## True where the engine sends its sound to the audio output itself (the
## browser): render() only gives silence and the volume comes from
## set_output_gain().
func plays_itself() -> bool:
	return false


## Linear volume of an engine that plays by itself.
func set_output_gain(_linear: float) -> void:
	pass


## Whether the audio output of an engine that plays by itself is running
## (a browser holds it back until the first click or key press).
func output_running() -> bool:
	return false


## What an engine that plays by itself has put out since the last call:
## {peak, sum (of squares, both channels), frames, finite}.
func take_output_stats() -> Dictionary:
	return {"peak": 0.0, "sum": 0.0, "frames": 0, "finite": true}


func synth_time() -> float:
	return 0.0


func active_voices() -> int:
	return 0
