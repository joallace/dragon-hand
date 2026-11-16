extends Node
## Headless test for the music player: StrudelSynth (native/strudel/src/synth.c),
## StrudelEngine (Strudel code -> events -> synth) and the Music autoload.
##   godot --headless res://tests/music_test.tscn
## Skips (PASS) when the extension library isn't built for this platform.
## It checks signals (pitch, level, silence, determinism), not how it sounds:
## listen with tools/music_render.tscn.

const RATE := 44100
## Event record layout (native/strudel/src/synth.h).
enum F { START, DURATION, SOURCE, FREQ, GAIN, ATTACK, DECAY, SUSTAIN, RELEASE, CUTOFF, RESONANCE,
	HCUTOFF, HRESONANCE, LPENV, LPATTACK, LPDECAY, LPSUSTAIN, LPRELEASE, PAN, DELAY, DELAYTIME,
	DELAYFEEDBACK, ROOM, ROOMSIZE, FMI, FMH, VIB, VIBMOD, SHAPE, CRUSH, NOISE, RESERVED, COUNT }
enum Src { SINE, SAWTOOTH, SQUARE, TRIANGLE, WHITE, PINK, BROWN, BD = 16, SD, HH, OH, CP, RIM, LT, MT, HT, CR, RD }
const SILENCE := 1e-4
const DEMO := "res://data/music/demo.strudel"
const SIGNAL_TIMEOUT_MSEC := 5000
## 120 cycles per minute, one kick per cycle; the `_$:` line is muted.
const KICK_SONG := """setcpm(120)
const kick = s("bd")
$: kick
_$: s("hh*16")
"""
const AUDIO_SETTLE_FRAMES := 10
const STOP_SETTLE_FRAMES := 30

var _failures := 0
var _events: Array = []  # [ok, message] from the engine / autoload under test


func _ready() -> void:
	if not StrudelEngine.available():
		print("PASS music_test skipped: strudel extension not built")
		get_tree().quit(0)
		return
	_test_synth_tone()
	_test_synth_sources()
	_test_synth_shaping()
	_test_synth_robustness()
	_test_runtime_limits()
	await _test_engine()
	await _test_autoload()
	print("music_test: %s" % ("FAIL" if _failures > 0 else "PASS"))
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", what])


func _synth() -> RefCounted:
	var synth: RefCounted = ClassDB.instantiate(&"StrudelSynth")
	synth.setup(RATE)
	return synth


## One event record; `fields` overrides the defaults (F index -> value).
func _event(start: float, source: int, fields: Dictionary = {}) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(F.COUNT)
	r[F.START] = start
	r[F.DURATION] = 0.5
	r[F.SOURCE] = source
	r[F.FREQ] = 440.0
	r[F.GAIN] = 0.5
	r[F.ATTACK] = 0.01
	r[F.DECAY] = 0.01
	r[F.SUSTAIN] = 1.0
	r[F.RELEASE] = 0.01
	r[F.RESONANCE] = 1.0
	r[F.HRESONANCE] = 1.0
	r[F.PAN] = 0.5
	r[F.DELAYTIME] = -1.0
	r[F.DELAYFEEDBACK] = -1.0
	r[F.ROOMSIZE] = -1.0
	r[F.FMH] = 1.0
	for key in fields:
		r[key] = fields[key]
	return r


func _seconds(s: float) -> int:
	return int(s * RATE)


func _peak(frames: PackedVector2Array, from: int = 0, to: int = -1) -> float:
	var peak := 0.0
	for i in range(from, frames.size() if to < 0 else to):
		peak = maxf(peak, maxf(absf(frames[i].x), absf(frames[i].y)))
	return peak


func _rms(frames: PackedVector2Array, from: int = 0, to: int = -1) -> float:
	var end := frames.size() if to < 0 else to
	var sum := 0.0
	for i in range(from, end):
		sum += frames[i].x * frames[i].x + frames[i].y * frames[i].y
	return sqrt(sum / maxf((end - from) * 2.0, 1.0))


## Frequency from upward zero crossings of the left channel.
func _frequency(frames: PackedVector2Array, from: int, to: int) -> float:
	var crossings := 0
	for i in range(from + 1, to):
		if frames[i - 1].x < 0.0 and frames[i].x >= 0.0:
			crossings += 1
	return crossings * float(RATE) / (to - from)


## RMS of the sample-to-sample difference: a rough measure of treble.
func _brightness(frames: PackedVector2Array) -> float:
	var sum := 0.0
	for i in range(1, frames.size()):
		var d := frames[i].x - frames[i - 1].x
		sum += d * d
	return sqrt(sum / frames.size())


func _render_one(record: PackedFloat64Array, seconds: float = 1.0) -> PackedVector2Array:
	var synth := _synth()
	synth.schedule(record)
	return synth.render(_seconds(seconds))


func _test_synth_tone() -> void:
	var synth := _synth()
	_check(synth.get_event_fields() == F.COUNT, "event layout has %d fields" % F.COUNT)
	synth.schedule(_event(0.0, Src.SINE))
	_check(synth.get_pending_events() == 1, "event queued")
	var out: PackedVector2Array = synth.render(_seconds(1.0))
	_check(is_equal_approx(synth.get_time(), 1.0), "clock advanced 1 s")
	var freq := _frequency(out, _seconds(0.1), _seconds(0.4))
	_check(absf(freq - 440.0) < 5.0, "sine at 440 Hz (measured %.1f)" % freq)
	# gain 0.5, centre pan = cos(45 deg) per channel.
	var expected := 0.5 * sqrt(0.5)
	var peak := _peak(out, _seconds(0.1), _seconds(0.4))
	_check(absf(peak - expected) < 0.01, "sustain level %.3f (expected %.3f)" % [peak, expected])
	_check(_peak(out, 0, _seconds(0.002)) < expected * 0.5, "attack ramps in")
	_check(_peak(out, _seconds(0.52)) < SILENCE, "silent after the release")
	_check(synth.get_active_voices() == 0, "voice freed")

	for wave: int in [Src.SAWTOOTH, Src.SQUARE, Src.TRIANGLE]:
		var w := _render_one(_event(0.0, wave, {F.FREQ: 220.0}))
		var measured := _frequency(w, _seconds(0.1), _seconds(0.4))
		_check(absf(measured - 220.0) < 4.0, "waveform %d at 220 Hz (measured %.1f)" % [wave, measured])

	var late := _synth()
	late.render(_seconds(0.5))
	late.schedule(_event(0.1, Src.SINE))
	_check(_peak(late.render(_seconds(0.1))) > 0.1, "an event in the past starts right away")


func _test_synth_sources() -> void:
	for source: int in [Src.WHITE, Src.PINK, Src.BROWN, Src.BD, Src.SD, Src.HH, Src.OH, Src.CP,
			Src.RIM, Src.LT, Src.MT, Src.HT, Src.CR, Src.RD]:
		var out := _render_one(_event(0.0, source, {F.GAIN: 0.8, F.FREQ: 0.0}), 3.0)
		var peak := _peak(out)
		_check(peak > 0.02 and peak <= 1.0, "source %d sounds (peak %.3f)" % [source, peak])
		if source >= Src.BD:
			_check(_peak(out, _seconds(2.5)) < SILENCE, "drum %d dies out" % source)
	var kick := _render_one(_event(0.0, Src.BD, {F.GAIN: 0.8}), 1.0)
	var tail := _frequency(kick, _seconds(0.15), _seconds(0.35))
	_check(tail > 35.0 and tail < 70.0, "kick settles near 48 Hz (measured %.1f)" % tail)
	_check(_peak(_render_one(_event(0.0, 99))) < SILENCE, "unknown source is silent")


func _test_synth_shaping() -> void:
	var open := _render_one(_event(0.0, Src.SAWTOOTH, {F.FREQ: 220.0}))
	var closed := _render_one(_event(0.0, Src.SAWTOOTH, {F.FREQ: 220.0, F.CUTOFF: 300.0}))
	_check(_brightness(closed) < _brightness(open) * 0.3, "low-pass removes treble")
	var swept := _render_one(_event(0.0, Src.SAWTOOTH, {F.FREQ: 220.0, F.CUTOFF: 300.0, F.LPENV: 4.0,
			F.LPATTACK: 0.005, F.LPDECAY: 0.1, F.LPSUSTAIN: 1.0, F.LPRELEASE: 0.1}))
	_check(_brightness(swept) > _brightness(closed) * 2.0, "filter envelope opens the low-pass")
	var thin := _render_one(_event(0.0, Src.SINE, {F.FREQ: 110.0, F.HCUTOFF: 2000.0}))
	_check(_rms(thin) < _rms(_render_one(_event(0.0, Src.SINE, {F.FREQ: 110.0}))) * 0.1, "high-pass removes bass")

	var left := _render_one(_event(0.0, Src.SINE, {F.PAN: 0.0}))
	var right_peak := 0.0
	for f in left:
		right_peak = maxf(right_peak, absf(f.y))
	_check(right_peak < SILENCE and _peak(left) > 0.4, "pan 0 is left only")

	var dry := _render_one(_event(0.0, Src.SINE, {F.DURATION: 0.1}))
	var echo := _render_one(_event(0.0, Src.SINE, {F.DURATION: 0.1, F.DELAY: 1.0, F.DELAYTIME: 0.25,
			F.DELAYFEEDBACK: 0.0}))
	_check(_peak(dry, _seconds(0.26), _seconds(0.34)) < SILENCE, "no echo without a delay send")
	_check(_peak(echo, _seconds(0.26), _seconds(0.34)) > 0.2, "delay repeats the note 0.25 s later")
	_check(_peak(echo, _seconds(0.52), _seconds(0.6)) < SILENCE, "no second repeat at feedback 0")
	var wet := _render_one(_event(0.0, Src.SINE, {F.DURATION: 0.1, F.ROOM: 1.0, F.ROOMSIZE: 0.8}), 2.0)
	var tail := _rms(wet, _seconds(0.3), _seconds(0.6))
	_check(tail > 0.001 and tail < 0.2, "reverb tail after the note (rms %.4f)" % tail)

	var vib := _render_one(_event(0.0, Src.SINE, {F.VIB: 6.0, F.VIBMOD: 1.0}))
	var fm := _render_one(_event(0.0, Src.SINE, {F.FMI: 3.0, F.FMH: 2.0}))
	var shaped := _render_one(_event(0.0, Src.SINE, {F.SHAPE: 0.8}))
	var crushed := _render_one(_event(0.0, Src.SINE, {F.CRUSH: 3.0}))
	var plain := _render_one(_event(0.0, Src.SINE))
	_check(vib != plain and _peak(vib) > 0.3, "vibrato changes the tone")
	_check(_brightness(fm) > _brightness(plain) * 1.5, "FM adds harmonics")
	_check(_rms(shaped) > _rms(plain) * 1.2, "waveshaper drives the signal")
	_check(_brightness(crushed) > _brightness(plain) * 1.2, "bit crush adds steps")


func _test_synth_robustness() -> void:
	var song := PackedFloat64Array()
	for i in 40:
		song.append_array(_event(i * 0.05, [Src.SINE, Src.SAWTOOTH, Src.BD, Src.CP, Src.HH][i % 5], {
				F.FREQ: 110.0 * (1 + i % 7), F.DELAY: 0.4, F.ROOM: 0.3, F.CUTOFF: 1500.0, F.LPENV: 2.0,
				F.VIB: 5.0, F.VIBMOD: 0.3, F.PAN: (i % 5) / 4.0}))
	var a := _synth()
	a.schedule(song)
	var whole: PackedVector2Array = a.render(_seconds(3.0))
	var b := _synth()
	b.schedule(song)
	_check(b.render(_seconds(3.0)) == whole, "same events render the same samples")
	var c := _synth()
	c.schedule(song)
	var pieces := PackedVector2Array()
	while pieces.size() < whole.size():
		pieces.append_array(c.render(mini(997, whole.size() - pieces.size())))
	_check(pieces == whole, "rendering in pieces changes nothing")
	a.reset()
	_check(a.get_time() == 0.0 and _peak(a.render(_seconds(0.5))) < SILENCE, "reset silences and rewinds")

	var flood := PackedFloat64Array()
	for i in 3000:
		flood.append_array(_event(0.01 * (i % 20), Src.SQUARE if i % 2 == 0 else Src.CP, {
				F.FREQ: 100.0 + i, F.GAIN: 1.0, F.DURATION: 2.0, F.DELAY: 1.0, F.DELAYFEEDBACK: 5.0,
				F.ROOM: 1.0, F.RESONANCE: 1000.0, F.CUTOFF: 1e9, F.CRUSH: 100.0, F.SHAPE: 5.0}))
	flood.append_array(_event(NAN, Src.SINE, {F.FREQ: INF, F.GAIN: NAN}))
	var d := _synth()
	d.schedule(flood)
	var loud: PackedVector2Array = d.render(_seconds(1.0))
	var finite := true
	for f in loud:
		finite = finite and is_finite(f.x) and is_finite(f.y) and absf(f.x) <= 1.0 and absf(f.y) <= 1.0
	_check(finite, "a flood of extreme events stays finite and within -1..1")
	_check(d.get_active_voices() <= 64, "voice count capped (%d)" % d.get_active_voices())
	_check(d.render(0).is_empty() and d.render(-5).is_empty(), "render(<= 0) is empty")

	# Values a song can produce must not poison the delay / reverb lines.
	var poisons := {
		"huge gain": {F.GAIN: 1e40, F.ROOM: 0.5},
		"infinite frequency": {F.FREQ: INF, F.DELAY: 0.5},
		"NaN sustain": {F.SUSTAIN: NAN, F.ROOM: 0.2},
		"huge filter envelope": {F.CUTOFF: 500.0, F.LPENV: 1e300, F.DELAY: 0.3},
		"NaN everywhere": {F.DURATION: NAN, F.ATTACK: NAN, F.CUTOFF: NAN, F.PAN: NAN, F.DELAY: NAN,
				F.DELAYTIME: NAN, F.ROOM: NAN, F.FMI: NAN, F.VIB: NAN, F.SHAPE: NAN, F.CRUSH: NAN},
	}
	for label: String in poisons:
		var p := _synth()
		p.schedule(_event(0.0, Src.SAWTOOTH, poisons[label]))
		p.render(_seconds(4.0))
		p.schedule(_event(4.0, Src.SINE))
		var after: PackedVector2Array = p.render(_seconds(0.4))
		var clean := true
		for f in after:
			clean = clean and is_finite(f.x) and is_finite(f.y)
		_check(clean and _peak(after, _seconds(0.1)) > 0.2, "%s does not poison later notes" % label)

	var clog := PackedFloat64Array()
	for i in 3000:
		clog.append_array(_event(1e8, Src.SINE))
	var e := _synth()
	e.schedule(clog)
	_check(e.get_pending_events() == 0, "events far in the future are refused (%d queued)" % e.get_pending_events())
	e.schedule(_event(0.0, Src.SINE))
	_check(_peak(e.render(_seconds(0.2))) > 0.2, "the queue still takes notes after a far-future flood")


func _on_loaded(ok: bool, message: String) -> void:
	_events.append([ok, message])


## Unthreaded engine: pump until a song_loaded arrives.
func _load(engine: StrudelEngine, code: String) -> Array:
	_events.clear()
	engine.load_song(code)
	engine.pump()
	await get_tree().process_frame
	return _events[0] if not _events.is_empty() else [false, "no song_loaded signal"]


func _play(engine: StrudelEngine, seconds: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var chunk := int(RATE * Tuning.music.lookahead * 0.5)
	while out.size() < _seconds(seconds):
		engine.pump()
		out.append_array(engine.render(chunk))
	return out


func _test_engine() -> void:
	var engine := StrudelEngine.new(RATE)
	engine.song_loaded.connect(_on_loaded)
	engine.start(false)

	var result: Array = await _load(engine, "note(\"a4\").s(\"sine\").sustain(1)")
	_check(result[0] and result[1] == "", "one-note song loads %s" % [result])
	var out := _play(engine, 2.0)
	# Default tempo is 0.5 cycles per second: one 2 s note per cycle.
	var freq := _frequency(out, _seconds(0.5), _seconds(1.5))
	_check(absf(freq - 440.0) < 3.0, "a4 plays at 440 Hz (measured %.1f)" % freq)

	engine.restart()
	result = await _load(engine, KICK_SONG)
	_check(result[0], "song with setcpm, a variable and $: lines loads %s" % [result])
	out = _play(engine, 2.0)
	var hits := 0
	for beat in 4:
		if _peak(out, _seconds(beat * 0.5), _seconds(beat * 0.5 + 0.05)) > 0.3 \
				and _peak(out, _seconds(beat * 0.5 + 0.4), _seconds(beat * 0.5 + 0.49)) < 0.05:
			hits += 1
	_check(hits == 4, "120 cycles per minute: a kick every 0.5 s (%d of 4)" % hits)

	result = await _load(engine, FileAccess.get_file_as_string(DEMO))
	_check(result[0] and result[1] == "", "demo song loads without warnings %s" % [result])
	out = _play(engine, 4.0)
	_check(_rms(out) > 0.02 and _peak(out) <= 1.0, "demo song is audible (rms %.3f, peak %.3f)" % [_rms(out), _peak(out)])

	result = await _load(engine, "note(\"c3\").nope()")
	_check(not result[0] and result[1].contains("not a function"), "bad song reports its error: %s" % result[1])
	_check(_rms(_play(engine, 1.0)) > 0.02, "the previous song keeps playing after a bad one")
	result = await _load(engine, "n(\"0 2 4\").scale(\"C:minor\").s(\"sine\")")
	_check(result[0] and result[1] == "", "scale() from Strudel's tonal package %s" % [result])
	result = await _load(engine, "s(\"bd piano\")")
	_check(result[0] and result[1].contains("piano"), "unknown sound is a warning: %s" % result[1])

	var start := Time.get_ticks_msec()
	result = await _load(engine, "(() => { for (;;) {} })()")
	var elapsed := Time.get_ticks_msec() - start
	_check(not result[0] and elapsed < Tuning.music.load_time_limit_msec * 3,
			"runaway song interrupted after %d ms" % elapsed)
	result = await _load(engine, "s(\"hh*4\")")
	_check(result[0], "engine usable after a runaway song")
	result = await _load(engine, "x".repeat(Tuning.music.max_song_bytes + 1))
	_check(not result[0] and result[1].contains("larger"), "oversized song rejected")

	await _test_hostile_songs(engine)

	engine.restart()
	engine.pump()
	_check(engine.synth_time() == 0.0 and _peak(engine.render(_seconds(0.5))) < SILENCE, "restart rewinds to silence")
	engine.stop()


## Songs a player could type that must not break the engine for the next one.
func _test_hostile_songs(engine: StrudelEngine) -> void:
	var good := "s(\"bd*4\")"
	var result: Array = await _load(engine, good)
	_check(result[0], "good song loads before the hostile ones")

	result = await _load(engine, "note(\"zz\").s(\"sine\")")
	_check(not result[0], "a song whose notes cannot be read is rejected: %s" % result[1])
	_check(_rms(_play(engine, 1.0)) > 0.02, "and the previous song keeps playing")

	result = await _load(engine, "(globalThis.music_query = () => [], globalThis.music_load = () => "
			+ "({ cps: 0.5, warnings: ['owned'] }), s(\"bd*4\"))")
	result = await _load(engine, good)
	_check(result[0] and result[1] == "", "a song cannot replace the host for the next song %s" % [result])
	_check(_rms(_play(engine, 1.0)) > 0.02, "next song still sounds")

	result = await _load(engine, "(Promise.resolve().then(function f() { Promise.resolve().then(f); "
			+ "Promise.resolve().then(f); }), s(\"bd\"))")
	_check(not result[0], "a song that floods the job queue fails: %s" % result[1])
	var start := Time.get_ticks_msec()
	result = await _load(engine, good)
	_check(result[0] and Time.get_ticks_msec() - start < Tuning.music.load_time_limit_msec,
			"the engine recovers right after it")
	_check(_rms(_play(engine, 1.0)) > 0.02, "and plays")

	for tempo: String in ["1e300", "1e5", "1e-9", "NaN", "-3"]:
		result = await _load(engine, "setcps(%s)\n$: s(\"bd*4\")" % tempo)
		start = Time.get_ticks_msec()
		var out := _play(engine, 1.0)
		var elapsed := Time.get_ticks_msec() - start
		var finite := true
		for f in out:
			finite = finite and is_finite(f.x)
		_check(finite and elapsed < 3000, "setcps(%s) cannot stall the scheduler (%d ms for 1 s)" % [tempo, elapsed])
	result = await _load(engine, good)
	_check(result[0] and _rms(_play(engine, 1.0)) > 0.02, "normal tempo plays after the extreme ones")

	result = await _load(engine, "s(\"bd constructor toString hasOwnProperty\")")
	_check(result[0] and result[1].contains("constructor") and result[1].contains("tostring"),
			"inherited property names are unknown sounds: %s" % result[1])
	result = await _load(engine, "note(\"<c3 zz>\").s(\"sine\")")
	_check(_rms(_play(engine, 4.0)) > 0.005, "one unreadable note does not silence the rest")
	result = await _load(engine, "s(\"sawtooth\").gain(1e40).room(.5).freq(Infinity).sustain(NaN)")
	_play(engine, 2.0)
	result = await _load(engine, good)
	var later := _play(engine, 1.0)
	var ok := _rms(later) > 0.02
	for f in later:
		ok = ok and is_finite(f.x) and is_finite(f.y)
	_check(ok, "extreme event values do not poison the next song")


func _test_runtime_limits() -> void:
	var js: RefCounted = ClassDB.instantiate(&"JsRuntime")
	js.set_time_limit_msec(200)
	var start := Time.get_ticks_msec()
	var sparse: Variant = js.eval("var a = []; a.length = 40000000; a")
	_check(js.has_error() and Time.get_ticks_msec() - start < 1000,
			"a huge sparse array is refused, not converted (%d ms)" % (Time.get_ticks_msec() - start))
	start = Time.get_ticks_msec()
	js.eval("var b = {}; b.a = b; b.b = b; b")
	_check(js.has_error() and Time.get_ticks_msec() - start < 1000,
			"a self-referencing object is refused (%d ms)" % (Time.get_ticks_msec() - start))
	_check(js.eval("[1, [2, 3], { k: 'v' }]") == [1, [2, 3], {"k": "v"}] and not js.has_error(),
			"ordinary values still convert")
	_check(sparse == null, "nothing returned for the refused value")


func _test_autoload() -> void:
	_check(Music.available(), "Music autoload available")
	_check(AudioServer.get_bus_index(Tuning.music.bus) >= 0, "Music bus exists")
	_check(Tuning.music.bus in AudioSettings.buses(), "Music bus has a volume setting")
	_events.clear()
	Music.song_started.connect(func(warnings: PackedStringArray) -> void: _events.append([true, "\n".join(warnings)]))
	Music.song_failed.connect(func(error: String) -> void: _events.append([false, error]))
	Music.play_file(DEMO)
	_check(Music.is_playing(), "playing after play_file")
	await _wait_for_event()
	_check(not _events.is_empty() and _events[0][0], "song_started from the worker thread %s" % [_events])
	_events.clear()
	Music.play("this is not a song(")
	await _wait_for_event()
	_check(not _events.is_empty() and not _events[0][0], "song_failed for a syntax error")
	_events.clear()
	Music.play_file("res://data/music/missing.strudel")
	_check(not _events.is_empty() and not _events[0][0], "song_failed for a missing file")
	Music.stop()
	_check(not Music.is_playing(), "stopped")
	# A song queued just before stop() must not start afterwards.
	_events.clear()
	Music.play_file(DEMO)
	Music.stop()
	for i in STOP_SETTLE_FRAMES:
		await get_tree().process_frame
	_check(_events.is_empty(), "stop() drops a song that was still loading %s" % [_events])
	await _test_tracks()
	# The audio server releases a stopped playback on its next mixes.
	for i in AUDIO_SETTLE_FRAMES:
		await get_tree().process_frame


## Named tracks, the user's replacement folder and the scene -> track map.
func _test_tracks() -> void:
	var engine := StrudelEngine.new(RATE)
	engine.song_loaded.connect(_on_loaded)
	engine.start(false)
	for track: StringName in [&"menu", &"match"]:
		var path := Music.track_path(track)
		_check(FileAccess.file_exists(path), "%s track file exists (%s)" % [track, path])
		engine.restart()
		var result: Array = await _load(engine, FileAccess.get_file_as_string(path))
		_check(result[0] and result[1] == "", "%s track loads without warnings %s" % [track, result])
		var out := _play(engine, 8.0)
		_check(_rms(out) > 0.03 and _peak(out) < 0.95, "%s track is audible and not clipping (rms %.3f, peak %.3f)"
				% [track, _rms(out), _peak(out)])
	engine.stop()

	_events.clear()
	Music.play_track(&"menu")
	await _wait_for_event()
	_check(not _events.is_empty() and _events[0][0] and Music.current_track == &"menu", "play_track starts the menu track")
	_events.clear()
	Music.play_track(&"menu")
	for i in STOP_SETTLE_FRAMES:
		await get_tree().process_frame
	_check(_events.is_empty(), "asking for the playing track again does not restart it")
	Music.play_track(&"nope")
	_check(not _events.is_empty() and not _events[0][0] and Music.current_track == &"menu",
			"unknown track fails and the current one stays")

	# user:// is shared by every worktree: use a folder of our own.
	var saved_dir := Tuning.music.user_dir
	Tuning.music.user_dir = "user://music_test_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(Tuning.music.user_dir)
	var user_file := Music.user_track_path(&"match")
	_check(user_file == Tuning.music.user_dir + "/match.strudel", "replacement path is <user_dir>/match.strudel")
	FileAccess.open(user_file, FileAccess.WRITE).store_string("s(\"hh*4\")")
	_events.clear()
	Music.play_track(&"match")
	await _wait_for_event()
	_check(not _events.is_empty() and _events[0][0] and Music.current_track == &"match",
			"a file in the user folder replaces the built-in track")
	Music.stop()
	FileAccess.open(user_file, FileAccess.WRITE).store_string("this is not a song(")
	_events.clear()
	Music.play_track(&"match")
	var deadline := Time.get_ticks_msec() + SIGNAL_TIMEOUT_MSEC
	while _events.size() < 2 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_events.size() == 2 and not _events[0][0] and _events[1][0] and Music.current_track == &"match",
			"a broken replacement falls back to the built-in track %s" % [_events])
	DirAccess.remove_absolute(user_file)
	DirAccess.remove_absolute(Tuning.music.user_dir)
	Tuning.music.user_dir = saved_dir

	Music.stop()
	var saved_scenes := Tuning.music.scene_tracks
	Tuning.music.scene_tracks = {"res://tests/": &"menu"}
	Music._on_scene_changed()
	_check(not Music.is_playing(), "no automatic music headless")
	Music.auto_play = true
	Music._on_scene_changed()
	_check(Music.is_playing() and Music.current_track == &"menu", "the scene's track starts on a scene change")
	Tuning.music.scene_tracks = {"res://somewhere/else/": &"match"}
	Music._on_scene_changed()
	_check(Music.current_track == &"menu", "a scene with no track leaves the music alone")
	Music.auto_play = false
	Tuning.music.scene_tracks = saved_scenes
	for prefix: String in saved_scenes:
		_check(Music.track_path(saved_scenes[prefix]) != "" and DirAccess.dir_exists_absolute(prefix),
				"scene folder %s maps to an existing track" % prefix)
	_check(Game.SCENE_MATCH.begins_with("res://scenes/match/") and Game.SCENE_MAIN_MENU.begins_with("res://scenes/menus/"),
			"the game's scenes fall under the mapped folders")
	Music.stop()


func _wait_for_event() -> void:
	var deadline := Time.get_ticks_msec() + SIGNAL_TIMEOUT_MSEC
	while _events.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
