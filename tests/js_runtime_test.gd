extends Node
## Headless test for the JsRuntime GDExtension (native/strudel) and for
## Strudel's unmodified pattern engine (third_party/strudel) running in it:
##   godot --headless res://tests/js_runtime_test.tscn
## Skips (PASS) when the extension library isn't built for this platform.

const BUNDLE := "res://presentation/audio/music/strudel_bundle.mjs"
const LOOP_LIMIT_MSEC := 200
const BENCH_CYCLES := 200
## SONG: 2 bass + 6 lead (3 euclid + 1 + 2) + 14 drums (4 bd + 2 sd + 8 hh).
const SONG_EVENTS_PER_CYCLE := 22

## A strudel.cc-style song: several statements, a variable, `$:` lines.
const SONG := """setcpm(90)
const bass = note("<c2 a1 f1 g1>*2").s("square").lpf(sine.range(300, 1800).slow(4)).decay(.1).sustain(0)
$: bass
$: n("0(3,8) 2 [4 3]").scale("C:minor").s("triangle").delay(.25).every(4, x => x.rev())
$: s("bd*4, ~ sd ~ sd, hh*8").gain(".8 .5")
_$: s("cp*16")
"""

var _failures := 0


func _ready() -> void:
	if not ClassDB.class_exists(&"JsRuntime"):
		print("PASS js_runtime_test skipped: JsRuntime extension not built")
		get_tree().quit(0)
		return
	_test_values()
	_test_errors_and_limits()
	_test_strudel()
	print("js_runtime_test: %s" % ("FAIL" if _failures > 0 else "PASS"))
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", what])


func _test_values() -> void:
	var js: RefCounted = ClassDB.instantiate(&"JsRuntime")
	_check(js.eval("1 + 2") == 3, "eval int")
	_check(js.eval("'a' + 'ç'") == "aç", "eval utf8 string")
	_check(js.eval("({ a: [1, 2.5, 'x', null, true], b: { c: 1 } })")
			== {"a": [1, 2.5, "x", null, true], "b": {"c": 1}}, "object to Dictionary")
	_check(js.eval("Promise.resolve(7).then((x) => x * 6)") == 42, "promise awaited")
	js.eval("globalThis.echo = (...args) => args")
	var args := [1, 2.5, "s", [1, 2], {"k": "v"}, null, true]
	_check(js.call_global("echo", args) == args, "call_global round trip")
	_check(js.eval("typeof Godot + typeof require + typeof std + typeof os + typeof fetch")
			== "undefined".repeat(5), "no host access from scripts")


func _test_errors_and_limits() -> void:
	var js: RefCounted = ClassDB.instantiate(&"JsRuntime")
	js.eval("null.x")
	_check(js.has_error() and js.get_error().contains("TypeError"), "exception reported")
	_check(js.eval("2") == 2 and not js.has_error(), "usable after an exception")
	js.eval("syntax error here")
	_check(js.get_error().contains("SyntaxError"), "syntax error reported")
	js.call_global("missing", [])
	_check(js.has_error(), "missing global function reported")
	_check(not js.run_module("import 'nope.mjs';", "main"), "unregistered module rejected")

	js.set_time_limit_msec(LOOP_LIMIT_MSEC)
	var start := Time.get_ticks_msec()
	js.eval("for (;;) {}")
	var elapsed := Time.get_ticks_msec() - start
	_check(js.has_error() and elapsed < LOOP_LIMIT_MSEC * 5,
			"infinite loop interrupted (%d ms)" % elapsed)
	_check(js.eval("3") == 3, "usable after an interrupt")

	js.add_module("lib/a.mjs", "export const a = 20;")
	js.add_module("lib/sub/b.mjs", "import { a } from '../a.mjs'; export const b = a + 1;")
	js.add_alias("bee", "lib/sub/b.mjs")
	_check(js.run_module("import { b } from 'bee'; globalThis.b = b + await Promise.resolve(1);",
			"main"), "module graph with alias, relative import and top-level await")
	_check(js.eval("b") == 22, "module result")


func _test_strudel() -> void:
	var js: RefCounted = ClassDB.instantiate(&"JsRuntime")
	js.add_module("music/bundle.mjs", FileAccess.get_file_as_string(BUNDLE))
	var start := Time.get_ticks_usec()
	var booted: bool = js.run_module("import 'music/bundle.mjs';", "boot")
	_check(booted, "strudel bundle boots in %d ms %s" % [(Time.get_ticks_usec() - start) / 1000, js.get_error()])
	if not booted:
		return
	var fields: int = js.call_global("music_fields", [])

	var info: Variant = js.call_global("music_load", ["note(\"c3 [e3 g3]\").s(\"sawtooth\").lpf(800)"])
	_check(info is Dictionary and info["cps"] == 0.5 and info["warnings"] == [],
			"simple pattern evaluates %s %s" % [info, js.get_error()])
	var events: Array = js.call_global("music_query", [0.0, 1.0, 10.0])
	_check(events.size() == 3 * fields, "3 events in cycle 0")
	if events.size() == 3 * fields:
		# start (s), duration (s), source (1 = sawtooth), frequency: c3 for half a 2 s cycle.
		_check(events[0] == 10.0 and events[1] == 1.0 and events[2] == 1 and absf(events[3] - 130.81) < 0.01,
				"first event %s" % [events.slice(0, 4)])
		_check(events[2 * fields] == 11.5 and absf(events[2 * fields + 3] - 196.0) < 0.01, "last event is g3 at 1.5 s")

	info = js.call_global("music_load", [SONG])
	_check(info is Dictionary and info["cps"] == 1.5, "song with $: lines, a variable, scale() and setcpm %s %s"
			% [info, js.get_error()])
	start = Time.get_ticks_usec()
	var total := 0
	for cycle in BENCH_CYCLES:
		total += (js.call_global("music_query", [float(cycle), float(cycle + 1), 0.0]) as Array).size() / fields
	var per_cycle := float(Time.get_ticks_usec() - start) / 1000.0 / BENCH_CYCLES
	_check(total == BENCH_CYCLES * SONG_EVENTS_PER_CYCLE, "song events (%d), muted _$: line left out" % total)
	print("INFO query cost: %.2f ms per cycle (%d events/cycle, into Godot Arrays)" % [per_cycle, total / BENCH_CYCLES])

	js.call_global("music_load", ["note(\"c3\").nope()"])
	_check(js.has_error(), "bad song reports an error: " + js.get_error().get_slice("\n", 0))
	_check((js.call_global("music_query", [0.0, 1.0, 0.0]) as Array).size() == SONG_EVENTS_PER_CYCLE * fields,
			"previous song kept after a bad one")
