#include "js_runtime.h"

#include <cstring>
#include <vector>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

namespace {

const int MAX_DEPTH = 32;
const int64_t DEFAULT_STACK_BYTES = 1024 * 1024;

std::string utf8(const String &p_string) {
	CharString cs = p_string.utf8();
	return std::string(cs.get_data(), cs.length());
}

String js_string(JSContext *p_ctx, JSValueConst p_value) {
	size_t len = 0;
	const char *chars = JS_ToCStringLen(p_ctx, &len, p_value);
	if (!chars) {
		return String();
	}
	String out = String::utf8(chars, (int64_t)len);
	JS_FreeCString(p_ctx, chars);
	return out;
}

// "a/b/c.mjs" + "../d.mjs" -> "a/d.mjs"
std::string resolve_relative(const std::string &p_base, const std::string &p_name) {
	std::vector<std::string> parts;
	std::string joined = p_base.substr(0, p_base.find_last_of('/') == std::string::npos ? 0 : p_base.find_last_of('/') + 1) + p_name;
	size_t start = 0;
	while (start <= joined.size()) {
		size_t end = joined.find('/', start);
		if (end == std::string::npos) {
			end = joined.size();
		}
		std::string part = joined.substr(start, end - start);
		if (part == "..") {
			if (!parts.empty()) {
				parts.pop_back();
			}
		} else if (!part.empty() && part != ".") {
			parts.push_back(part);
		}
		start = end + 1;
	}
	std::string out;
	for (const std::string &part : parts) {
		out += (out.empty() ? "" : "/") + part;
	}
	return out;
}

} // namespace

void JsRuntime::_bind_methods() {
	ClassDB::bind_method(D_METHOD("add_module", "name", "source"), &JsRuntime::add_module);
	ClassDB::bind_method(D_METHOD("add_alias", "specifier", "name"), &JsRuntime::add_alias);
	ClassDB::bind_method(D_METHOD("run_module", "source", "name"), &JsRuntime::run_module);
	ClassDB::bind_method(D_METHOD("eval", "source"), &JsRuntime::eval);
	ClassDB::bind_method(D_METHOD("call_global", "function", "args"), &JsRuntime::call_global);
	ClassDB::bind_method(D_METHOD("get_error"), &JsRuntime::get_error);
	ClassDB::bind_method(D_METHOD("has_error"), &JsRuntime::has_error);
	ClassDB::bind_method(D_METHOD("set_time_limit_msec", "msec"), &JsRuntime::set_time_limit_msec);
	ClassDB::bind_method(D_METHOD("get_time_limit_msec"), &JsRuntime::get_time_limit_msec);
	ClassDB::bind_method(D_METHOD("set_memory_limit", "bytes"), &JsRuntime::set_memory_limit);
}

JsRuntime::JsRuntime() {
	rt = JS_NewRuntime();
	JS_SetMaxStackSize(rt, DEFAULT_STACK_BYTES);
	ctx = JS_NewContext(rt);
	JS_SetContextOpaque(ctx, this);
	JS_SetModuleLoaderFunc(rt, &JsRuntime::normalize_module, &JsRuntime::load_module, this);
	JS_SetInterruptHandler(rt, &JsRuntime::interrupt, this);
	JSValue global = JS_GetGlobalObject(ctx);
	JS_SetPropertyStr(ctx, global, "print", JS_NewCFunction(ctx, &JsRuntime::js_print, "print", 1));
	JS_FreeValue(ctx, global);
}

JsRuntime::~JsRuntime() {
	JS_UpdateStackTop(rt);
	JS_FreeContext(ctx);
	JS_FreeRuntime(rt);
}

void JsRuntime::add_module(const String &p_name, const String &p_source) {
	modules[utf8(p_name)] = utf8(p_source);
}

void JsRuntime::add_alias(const String &p_specifier, const String &p_name) {
	aliases[utf8(p_specifier)] = utf8(p_name);
}

void JsRuntime::set_memory_limit(int64_t p_bytes) {
	JS_SetMemoryLimit(rt, p_bytes > 0 ? (size_t)p_bytes : 0);
}

void JsRuntime::begin_call() {
	// The runtime may be driven from a worker thread: stack checks are
	// relative to the calling thread's stack.
	JS_UpdateStackTop(rt);
	error = String();
	has_deadline = time_limit_msec > 0;
	if (has_deadline) {
		deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(time_limit_msec);
	}
}

bool JsRuntime::run_module(const String &p_source, const String &p_name) {
	begin_call();
	std::string source = utf8(p_source);
	std::string name = utf8(p_name);
	finish(JS_Eval(ctx, source.c_str(), source.size(), name.c_str(), JS_EVAL_TYPE_MODULE));
	return error.is_empty();
}

Variant JsRuntime::eval(const String &p_source) {
	begin_call();
	std::string source = utf8(p_source);
	return finish(JS_Eval(ctx, source.c_str(), source.size(), "<eval>", JS_EVAL_TYPE_GLOBAL));
}

Variant JsRuntime::call_global(const String &p_function, const Array &p_args) {
	begin_call();
	JSValue global = JS_GetGlobalObject(ctx);
	JSValue function = JS_GetPropertyStr(ctx, global, utf8(p_function).c_str());
	if (!JS_IsFunction(ctx, function)) {
		error = "call_global: '" + p_function + "' is not a function";
		JS_FreeValue(ctx, function);
		JS_FreeValue(ctx, global);
		return Variant();
	}
	std::vector<JSValue> args;
	for (int64_t i = 0; i < p_args.size(); i++) {
		args.push_back(to_js(p_args[i], 0));
	}
	JSValue result = JS_Call(ctx, function, global, (int)args.size(), args.data());
	for (JSValue &arg : args) {
		JS_FreeValue(ctx, arg);
	}
	JS_FreeValue(ctx, function);
	JS_FreeValue(ctx, global);
	return finish(result);
}

bool JsRuntime::drain_jobs() {
	JSContext *job_ctx = nullptr;
	for (;;) {
		int status = JS_ExecutePendingJob(rt, &job_ctx);
		if (status == 0) {
			return true;
		}
		if (status < 0) {
			take_exception();
			return false;
		}
	}
}

void JsRuntime::take_exception() {
	JSValue exception = JS_GetException(ctx);
	String message = js_string(ctx, exception);
	if (JS_IsError(exception)) {
		JSValue stack = JS_GetPropertyStr(ctx, exception, "stack");
		if (JS_IsString(stack)) {
			message += "\n" + js_string(ctx, stack);
		}
		JS_FreeValue(ctx, stack);
	}
	JS_FreeValue(ctx, exception);
	error = message.is_empty() ? String("unknown JavaScript error") : message;
}

Variant JsRuntime::finish(JSValue p_value) {
	Variant out;
	if (JS_IsException(p_value)) {
		take_exception();
	} else if (drain_jobs()) {
		if (JS_IsPromise(p_value)) {
			JSPromiseStateEnum state = JS_PromiseState(ctx, p_value);
			JSValue settled = JS_PromiseResult(ctx, p_value);
			if (state == JS_PROMISE_FULFILLED) {
				out = to_variant(settled, 0);
			} else if (state == JS_PROMISE_REJECTED) {
				JS_Throw(ctx, JS_DupValue(ctx, settled));
				take_exception();
			} else {
				error = "promise never settled (nothing left to run)";
			}
			JS_FreeValue(ctx, settled);
		} else {
			out = to_variant(p_value, 0);
		}
	}
	JS_FreeValue(ctx, p_value);
	has_deadline = false;
	return out;
}

Variant JsRuntime::to_variant(JSValueConst p_value, int p_depth) {
	if (JS_IsBool(p_value)) {
		return (bool)JS_ToBool(ctx, p_value);
	}
	if (JS_VALUE_GET_TAG(p_value) == JS_TAG_INT) {
		return (int64_t)JS_VALUE_GET_INT(p_value);
	}
	if (JS_IsNumber(p_value)) {
		double number = 0.0;
		JS_ToFloat64(ctx, &number, p_value);
		return number;
	}
	if (JS_IsBigInt(p_value)) {
		int64_t number = 0;
		JS_ToInt64Ext(ctx, &number, p_value);
		return number;
	}
	if (JS_IsString(p_value)) {
		return js_string(ctx, p_value);
	}
	if (!JS_IsObject(p_value) || JS_IsFunction(ctx, p_value) || p_depth >= MAX_DEPTH) {
		return Variant();
	}
	if (JS_IsArray(p_value)) {
		Array out;
		int64_t length = 0;
		JS_GetLength(ctx, p_value, &length);
		for (int64_t i = 0; i < length; i++) {
			JSValue item = JS_GetPropertyUint32(ctx, p_value, (uint32_t)i);
			out.push_back(to_variant(item, p_depth + 1));
			JS_FreeValue(ctx, item);
		}
		return out;
	}
	Dictionary out;
	JSPropertyEnum *props = nullptr;
	uint32_t count = 0;
	if (JS_GetOwnPropertyNames(ctx, &props, &count, p_value, JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY) < 0) {
		JS_FreeValue(ctx, JS_GetException(ctx));
		return out;
	}
	for (uint32_t i = 0; i < count; i++) {
		JSValue key = JS_AtomToString(ctx, props[i].atom);
		JSValue item = JS_GetProperty(ctx, p_value, props[i].atom);
		out[js_string(ctx, key)] = to_variant(item, p_depth + 1);
		JS_FreeValue(ctx, item);
		JS_FreeValue(ctx, key);
	}
	JS_FreePropertyEnum(ctx, props, count);
	return out;
}

JSValue JsRuntime::to_js(const Variant &p_value, int p_depth) {
	switch (p_value.get_type()) {
		case Variant::BOOL:
			return JS_NewBool(ctx, (bool)p_value);
		case Variant::INT:
			return JS_NewInt64(ctx, (int64_t)p_value);
		case Variant::FLOAT:
			return JS_NewFloat64(ctx, (double)p_value);
		case Variant::STRING:
		case Variant::STRING_NAME: {
			std::string text = utf8(p_value);
			return JS_NewStringLen(ctx, text.c_str(), text.size());
		}
		case Variant::ARRAY: {
			JSValue out = JS_NewArray(ctx);
			if (p_depth < MAX_DEPTH) {
				Array array = p_value;
				for (int64_t i = 0; i < array.size(); i++) {
					JS_SetPropertyUint32(ctx, out, (uint32_t)i, to_js(array[i], p_depth + 1));
				}
			}
			return out;
		}
		case Variant::DICTIONARY: {
			JSValue out = JS_NewObject(ctx);
			if (p_depth < MAX_DEPTH) {
				Dictionary dict = p_value;
				Array keys = dict.keys();
				for (int64_t i = 0; i < keys.size(); i++) {
					JS_SetPropertyStr(ctx, out, utf8(String(keys[i])).c_str(), to_js(dict[keys[i]], p_depth + 1));
				}
			}
			return out;
		}
		default:
			return JS_NULL;
	}
}

char *JsRuntime::normalize_module(JSContext *p_ctx, const char *p_base, const char *p_name, void *p_opaque) {
	JsRuntime *self = static_cast<JsRuntime *>(p_opaque);
	std::string name = p_name;
	auto alias = self->aliases.find(name);
	if (alias != self->aliases.end()) {
		name = alias->second;
	} else if (name.rfind("./", 0) == 0 || name.rfind("../", 0) == 0) {
		name = resolve_relative(p_base, name);
	}
	return js_strdup(p_ctx, name.c_str());
}

JSModuleDef *JsRuntime::load_module(JSContext *p_ctx, const char *p_name, void *p_opaque) {
	JsRuntime *self = static_cast<JsRuntime *>(p_opaque);
	auto found = self->modules.find(p_name);
	if (found == self->modules.end()) {
		JS_ThrowReferenceError(p_ctx, "module '%s' is not registered", p_name);
		return nullptr;
	}
	JSValue compiled = JS_Eval(p_ctx, found->second.c_str(), found->second.size(), p_name,
			JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
	if (JS_IsException(compiled)) {
		return nullptr;
	}
	JSModuleDef *module = static_cast<JSModuleDef *>(JS_VALUE_GET_PTR(compiled));
	JS_FreeValue(p_ctx, compiled);
	return module;
}

int JsRuntime::interrupt(JSContext *p_ctx, void *p_opaque) {
	JsRuntime *self = static_cast<JsRuntime *>(p_opaque);
	return self->has_deadline && std::chrono::steady_clock::now() > self->deadline;
}

JSValue JsRuntime::js_print(JSContext *p_ctx, JSValueConst p_this, int p_argc, JSValueConst *p_argv) {
	String line;
	for (int i = 0; i < p_argc; i++) {
		line += (i > 0 ? " " : "") + js_string(p_ctx, p_argv[i]);
	}
	UtilityFunctions::print(line);
	return JS_UNDEFINED;
}

} // namespace godot
