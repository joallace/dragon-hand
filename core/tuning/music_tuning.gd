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

@export_group("Tracks")
## Track name -> song file (Strudel code as plain text).
@export var tracks: Dictionary[StringName, String] = {
	&"menu": "res://data/music/menu.strudel",
	&"match": "res://data/music/match.strudel",
}
## A file named <track>.strudel in this folder replaces the built-in track,
## without rebuilding the game. If it fails to load, the built-in one plays.
@export var user_dir: String = "user://music"
## Scene path prefix -> track that plays while such a scene is current.
## Scenes matching no prefix leave the music as it is.
@export var scene_tracks: Dictionary[String, StringName] = {
	"res://scenes/menus/": &"menu",
	"res://scenes/match/": &"match",
}
## Follow scene_tracks automatically (never headless; see Music.auto_play).
@export var auto_play: bool = true

@export_group("Scheduling")
## How far ahead of the synth clock events are queued. Must cover the stream
## buffer plus a slow frame; it is also how long a song change takes to be
## heard.
@export var lookahead: float = 0.5
## A cycle is queried in at least this many slices (power of two, so slice
## boundaries are exact floats and no event is queried twice or skipped);
## slow tempos use more, keeping a slice under half the lookahead.
@export var query_steps_per_cycle: int = 8
## Query slices per scheduling pass at most; a tempo too fast to keep up
## with falls behind instead of holding the music thread.
@export var max_steps_per_pump: int = 32
## Tempo in cycles per second: Strudel's default, and the range a song's
## setcps / setcpm is clamped to.
@export var default_cps: float = 0.5
@export var min_cps: float = 0.02
@export var max_cps: float = 8.0
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
## Web: a song's worker must import the Strudel bundle within this time, and
## answer an event query within this many rendered frames, or it is
## terminated (the frame count, not a clock, so a hidden tab doesn't trip it).
@export var web_boot_time_limit_msec: int = 15000
@export var web_reply_timeout_frames: int = 240
## Largest song text accepted.
@export var max_song_bytes: int = 256 * 1024
