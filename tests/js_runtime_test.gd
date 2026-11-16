extends Node
## Headless test for the JsRuntime GDExtension (native/js_runtime) and for
## Strudel's unmodified pattern engine (third_party/strudel) running in it:
##   godot --headless res://tests/js_runtime_test.tscn
## Skips (PASS) when the extension library isn't built for this platform.

const STRUDEL_DIR := "res://third_party/strudel"
const FRACTION_FILE := "res://third_party/fraction.js/fraction.mjs"
const LOOP_LIMIT_MSEC := 200
const BENCH_CYCLES := 200
## SONG: 2 bass + 6 lead (3 euclid + 1 + 2) + 14 drums (4 bd + 2 sd + 8 hh).
const SONG_EVENTS_PER_CYCLE := 22

## What Strudel's core expects outside a browser, then the engine itself.
const BOOT := """
globalThis.console = { log: print, warn: print, error: print, info: print, debug: print };
globalThis.performance = { now: () => Date.now() };
const core = await import('strudel/core/index.mjs');
const mini = await import('strudel/mini/index.mjs');
mini.miniAllStrings();
await core.evalScope(core, mini);
let current = core.silence;
globalThis.strudel_load = async (code) => {
  current = (await core.evaluate(code)).pattern;
  return true;
};
globalThis.strudel_query = (begin, end) => current.queryArc(begin, end)
  .filter((hap) => hap.hasOnset())
  .map((hap) => ({ begin: hap.whole.begin.valueOf(), end: hap.whole.end.valueOf(), value: hap.value }));
"""

const SONG := """stack(
  note("<c2 a1 f1 g1>*2").s("square").lpf(sine.range(300, 1800).slow(4)).decay(.1).sustain(0),
  note("e4(3,8) g4 [b4 a4]").s("triangle").delay(.25).every(4, x => x.rev()),
  s("bd*4, ~ sd ~ sd, hh*8").gain(".8 .5")
)"""

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


func _add_dir(js: RefCounted, dir: String, prefix: String) -> int:
	var count := 0
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in ["mjs", "js"]:
			js.add_module(prefix + file, FileAccess.get_file_as_string(dir.path_join(file)))
			count += 1
	return count


func _test_strudel() -> void:
	var js: RefCounted = ClassDB.instantiate(&"JsRuntime")
	var files := _add_dir(js, STRUDEL_DIR + "/core", "strudel/core/")
	files += _add_dir(js, STRUDEL_DIR + "/mini", "strudel/mini/")
	js.add_module("fraction.mjs", FileAccess.get_file_as_string(FRACTION_FILE))
	js.add_alias("fraction.js", "fraction.mjs")
	js.add_alias("@strudel/core", "strudel/core/index.mjs")
	js.add_alias("@strudel/core/fraction.mjs", "strudel/core/fraction.mjs")
	js.add_alias("@strudel/mini", "strudel/mini/index.mjs")
	_check(files > 20, "strudel sources found (%d files)" % files)

	var start := Time.get_ticks_usec()
	var booted: bool = js.run_module(BOOT, "boot")
	_check(booted, "strudel boots in %d ms %s" % [(Time.get_ticks_usec() - start) / 1000, js.get_error()])
	if not booted:
		return

	_check(js.call_global("strudel_load", ["note(\"c3 [e3 g3]\").s(\"sawtooth\").lpf(800)"]) == true,
			"simple pattern evaluates " + js.get_error())
	var events: Array = js.call_global("strudel_query", [0.0, 1.0])
	_check(events.size() == 3, "3 events in cycle 0")
	if events.size() == 3:
		_check(events[0] == {"begin": 0, "end": 0.5, "value": {"note": "c3", "s": "sawtooth", "cutoff": 800}},
				"first event %s" % [events[0]])
		_check(is_equal_approx(events[2]["begin"], 0.75) and events[2]["value"]["note"] == "g3", "last event")

	_check(js.call_global("strudel_load", [SONG]) == true, "song with arrow function and signals " + js.get_error())
	start = Time.get_ticks_usec()
	var total := 0
	for cycle in BENCH_CYCLES:
		total += (js.call_global("strudel_query", [float(cycle), float(cycle + 1)]) as Array).size()
	var per_cycle := float(Time.get_ticks_usec() - start) / 1000.0 / BENCH_CYCLES
	_check(total == BENCH_CYCLES * SONG_EVENTS_PER_CYCLE, "song events (%d)" % total)
	print("INFO query cost: %.2f ms per cycle (%d events/cycle, into Godot Arrays)" % [per_cycle, total / BENCH_CYCLES])

	js.call_global("strudel_load", ["note(\"c3\").nope()"])
	_check(js.has_error(), "bad song reports an error: " + js.get_error().get_slice("\n", 0))
	_check((js.call_global("strudel_query", [0.0, 1.0]) as Array).size() == SONG_EVENTS_PER_CYCLE, "previous song kept after a bad one")
