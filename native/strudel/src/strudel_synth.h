#pragma once

#include <mutex>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include "synth.h"

namespace godot {

// The music synth (synth.c) as a Godot object. schedule() may be called from
// a worker thread while another thread calls render().
class StrudelSynth : public RefCounted {
	GDCLASS(StrudelSynth, RefCounted)

public:
	StrudelSynth();
	~StrudelSynth() override;

	void setup(double p_sample_rate);
	void reset();
	// Doubles per event in schedule() (layout in synth.h).
	int get_event_fields() const { return SYN_EVENT_FIELDS; }
	void schedule(const PackedFloat64Array &p_records);
	// Stereo frames (x = left, y = right); advances the synth clock.
	PackedVector2Array render(int p_frames);
	double get_time();
	int get_active_voices();
	int get_pending_events();
	void set_master_gain(double p_gain);

protected:
	static void _bind_methods();

private:
	Synth *synth = nullptr;
	std::mutex mutex;
};

} // namespace godot
