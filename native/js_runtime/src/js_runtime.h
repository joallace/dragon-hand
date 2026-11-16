#pragma once

#include <chrono>
#include <string>
#include <unordered_map>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

extern "C" {
#include "quickjs.h"
}

namespace godot {

// A sandboxed JavaScript context (quickjs-ng). The script sees nothing of the
// engine: only `print(...)` and the modules registered with add_module().
// Values cross as plain data (null, bool, number, String, Array, Dictionary).
// One runtime may be used from any thread, but only one thread at a time.
class JsRuntime : public RefCounted {
	GDCLASS(JsRuntime, RefCounted)

public:
	JsRuntime();
	~JsRuntime() override;

	// Module sources by name ("strudel/core/index.mjs"). Relative imports
	// resolve against the importing module's name; bare specifiers go
	// through add_alias().
	void add_module(const String &p_name, const String &p_source);
	void add_alias(const String &p_specifier, const String &p_name);

	// Runs p_source as an ES module (top-level await allowed). False on error.
	bool run_module(const String &p_source, const String &p_name);
	// Evaluates global code and returns its value; a promise is awaited.
	Variant eval(const String &p_source);
	// Calls a global function with plain-data arguments.
	Variant call_global(const String &p_function, const Array &p_args);

	// Empty when the last run_module / eval / call_global succeeded.
	String get_error() const { return error; }
	bool has_error() const { return !error.is_empty(); }

	// 0 = unlimited. The time limit covers one run_module / eval / call_global.
	void set_time_limit_msec(int p_msec) { time_limit_msec = p_msec; }
	int get_time_limit_msec() const { return time_limit_msec; }
	void set_memory_limit(int64_t p_bytes);

protected:
	static void _bind_methods();

private:
	JSRuntime *rt = nullptr;
	JSContext *ctx = nullptr;
	std::unordered_map<std::string, std::string> modules;
	std::unordered_map<std::string, std::string> aliases;
	String error;
	int time_limit_msec = 0;
	std::chrono::steady_clock::time_point deadline;
	bool has_deadline = false;

	void begin_call();
	// Consumes p_value: awaits promises, records exceptions, converts.
	Variant finish(JSValue p_value);
	bool drain_jobs();
	void take_exception();

	Variant to_variant(JSValueConst p_value, int p_depth);
	JSValue to_js(const Variant &p_value, int p_depth);

	static char *normalize_module(JSContext *p_ctx, const char *p_base, const char *p_name, void *p_opaque);
	static JSModuleDef *load_module(JSContext *p_ctx, const char *p_name, void *p_opaque);
	static int interrupt(JSContext *p_ctx, void *p_opaque);
	static JSValue js_print(JSContext *p_ctx, JSValueConst p_this, int p_argc, JSValueConst *p_argv);
};

} // namespace godot
