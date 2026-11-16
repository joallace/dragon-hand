class_name MusicTuning
extends Resource
## Music player (presentation only). Edit data/tuning/music.tres.
## Songs are Strudel code (data/music/*.strudel) played by the Music autoload
## through StrudelEngine. Times in seconds unless the name says otherwise.

@export_group("Mix")
@export var enabled: bool = true
## The player's volume for this bus lives in user://audio.cfg (AudioSettings).
@export var bus: StringName = &"Music"
@export var volume_db: float = -8.0
## Synth output gain before its soft clipper.
@export var master_gain: float = 0.7

@export_group("Scheduling")
## How far ahead of the synth clock events are queued. Must cover the stream
## buffer plus a slow frame; it is also how long a song change takes to be
## heard.
@export var lookahead: float = 0.5
## A cycle is queried in this many slices (power of two, so slice boundaries
## are exact floats and no event is queried twice or skipped).
@export var query_steps_per_cycle: int = 8
## Worker thread sleep between scheduling passes.
@export var worker_idle_msec: int = 15
## AudioStreamGenerator buffer: latency vs. safety against frame hitches.
@export var buffer_length: float = 0.2

@export_group("Script limits")
## Wall-clock limit for evaluating a song / for one event query, so a
## runaway script cannot hang the music thread.
@export var load_time_limit_msec: int = 2000
@export var query_time_limit_msec: int = 250
@export var memory_limit_bytes: int = 128 * 1024 * 1024
## Largest song text accepted.
@export var max_song_bytes: int = 256 * 1024
