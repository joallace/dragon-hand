#include "strudel_synth.h"

#include <cstdlib>

#include <godot_cpp/core/class_db.hpp>

namespace godot {

namespace {
const double DEFAULT_SAMPLE_RATE = 44100.0;
const int MAX_RENDER_FRAMES = 1 << 20;
} // namespace

void StrudelSynth::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "sample_rate"), &StrudelSynth::setup);
	ClassDB::bind_method(D_METHOD("reset"), &StrudelSynth::reset);
	ClassDB::bind_method(D_METHOD("get_event_fields"), &StrudelSynth::get_event_fields);
	ClassDB::bind_method(D_METHOD("schedule", "records"), &StrudelSynth::schedule);
	ClassDB::bind_method(D_METHOD("render", "frames"), &StrudelSynth::render);
	ClassDB::bind_method(D_METHOD("get_time"), &StrudelSynth::get_time);
	ClassDB::bind_method(D_METHOD("get_active_voices"), &StrudelSynth::get_active_voices);
	ClassDB::bind_method(D_METHOD("get_pending_events"), &StrudelSynth::get_pending_events);
	ClassDB::bind_method(D_METHOD("set_master_gain", "gain"), &StrudelSynth::set_master_gain);
}

StrudelSynth::StrudelSynth() {
	synth = static_cast<Synth *>(std::malloc(syn_sizeof()));
	syn_init(synth, (float)DEFAULT_SAMPLE_RATE);
}

StrudelSynth::~StrudelSynth() {
	std::free(synth);
}

void StrudelSynth::setup(double p_sample_rate) {
	std::lock_guard<std::mutex> lock(mutex);
	syn_init(synth, (float)p_sample_rate);
}

void StrudelSynth::reset() {
	std::lock_guard<std::mutex> lock(mutex);
	syn_reset(synth);
}

void StrudelSynth::schedule(const PackedFloat64Array &p_records) {
	std::lock_guard<std::mutex> lock(mutex);
	syn_schedule(synth, p_records.ptr(), (int)(p_records.size() / SYN_EVENT_FIELDS));
}

PackedVector2Array StrudelSynth::render(int p_frames) {
	PackedVector2Array out;
	if (p_frames <= 0 || p_frames > MAX_RENDER_FRAMES) {
		return out;
	}
	out.resize(p_frames);
	static_assert(sizeof(Vector2) == 2 * sizeof(float), "render() writes floats straight into Vector2s");
	std::lock_guard<std::mutex> lock(mutex);
	syn_render(synth, reinterpret_cast<float *>(out.ptrw()), p_frames);
	return out;
}

double StrudelSynth::get_time() {
	std::lock_guard<std::mutex> lock(mutex);
	return syn_time(synth);
}

int StrudelSynth::get_active_voices() {
	std::lock_guard<std::mutex> lock(mutex);
	return syn_active_voices(synth);
}

int StrudelSynth::get_pending_events() {
	std::lock_guard<std::mutex> lock(mutex);
	return syn_pending_events(synth);
}

void StrudelSynth::set_master_gain(double p_gain) {
	std::lock_guard<std::mutex> lock(mutex);
	syn_set_master_gain(synth, (float)p_gain);
}

} // namespace godot
