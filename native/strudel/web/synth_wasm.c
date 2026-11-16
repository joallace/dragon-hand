/* WebAssembly wrapper around synth.c for the web build (no libc: one static
 * synth, fixed buffers the page reads and writes through the module's
 * memory). Built by build_wasm.sh. */
#include "../src/synth.c"

#define WASM_MAX_EVENTS 512
#define WASM_MAX_FRAMES 8192
#define EXPORT(name) __attribute__((export_name(#name)))

static Synth synth;
static double event_buffer[WASM_MAX_EVENTS * SYN_EVENT_FIELDS];
static float out_buffer[WASM_MAX_FRAMES * 2];

/* The compiler may still emit calls to these for struct copies. */
void *memcpy(void *to, const void *from, unsigned long bytes) {
	unsigned char *d = (unsigned char *)to;
	const unsigned char *s = (const unsigned char *)from;
	while (bytes--) {
		*d++ = *s++;
	}
	return to;
}

void *memset(void *to, int value, unsigned long bytes) {
	unsigned char *d = (unsigned char *)to;
	while (bytes--) {
		*d++ = (unsigned char)value;
	}
	return to;
}

EXPORT(music_init) void music_init(float sample_rate) {
	syn_init(&synth, sample_rate);
}

EXPORT(music_reset) void music_reset(void) {
	syn_reset(&synth);
}

EXPORT(music_event_fields) int music_event_fields(void) {
	return SYN_EVENT_FIELDS;
}

EXPORT(music_max_events) int music_max_events(void) {
	return WASM_MAX_EVENTS;
}

EXPORT(music_max_frames) int music_max_frames(void) {
	return WASM_MAX_FRAMES;
}

/* Where the page writes event records before music_schedule(count). */
EXPORT(music_event_buffer) double *music_event_buffer(void) {
	return event_buffer;
}

EXPORT(music_schedule) void music_schedule(int count) {
	if (count > 0) {
		syn_schedule(&synth, event_buffer, count < WASM_MAX_EVENTS ? count : WASM_MAX_EVENTS);
	}
}

/* Renders up to music_max_frames() interleaved stereo frames; returns where. */
EXPORT(music_render) float *music_render(int frames) {
	if (frames < 0) {
		frames = 0;
	}
	syn_render(&synth, out_buffer, frames < WASM_MAX_FRAMES ? frames : WASM_MAX_FRAMES);
	return out_buffer;
}

EXPORT(music_time) double music_time(void) {
	return syn_time(&synth);
}

EXPORT(music_set_master_gain) void music_set_master_gain(float gain) {
	syn_set_master_gain(&synth, gain);
}
