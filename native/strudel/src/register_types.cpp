#include <gdextension_interface.h>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

#include "js_runtime.h"
#include "strudel_synth.h"

using namespace godot;

static void initialize_strudel(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		GDREGISTER_CLASS(JsRuntime);
		GDREGISTER_CLASS(StrudelSynth);
	}
}

static void uninitialize_strudel(ModuleInitializationLevel p_level) {
}

extern "C" {
GDExtensionBool GDE_EXPORT strudel_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_strudel);
	init_obj.register_terminator(uninitialize_strudel);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
