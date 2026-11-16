/* Music synth core: renders scheduled note events to interleaved stereo
 * float PCM. Plain C with no libc/libm dependency so the same file builds
 * into the GDExtension (desktop) and a freestanding WebAssembly module (web).
 *
 * An event is SYN_EVENT_FIELDS doubles (see the enum). Everything that needs
 * pow/log (note -> Hz, dB -> linear) is done by the caller. */
#ifndef STRUDEL_SYNTH_H
#define STRUDEL_SYNTH_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
	SYN_START, /* seconds on the synth clock (0 = syn_init / syn_reset) */
	SYN_DURATION, /* seconds the note is held before its release */
	SYN_SOURCE, /* SYN_SRC_* */
	SYN_FREQ, /* Hz; <= 0 keeps a drum's own pitch */
	SYN_GAIN, /* linear */
	SYN_ATTACK, /* seconds */
	SYN_DECAY,
	SYN_SUSTAIN, /* 0..1 */
	SYN_RELEASE,
	SYN_CUTOFF, /* low-pass Hz, <= 0 = off */
	SYN_RESONANCE, /* linear Q */
	SYN_HCUTOFF, /* high-pass Hz, <= 0 = off */
	SYN_HRESONANCE,
	SYN_LPENV, /* low-pass envelope depth in octaves */
	SYN_LPATTACK,
	SYN_LPDECAY,
	SYN_LPSUSTAIN,
	SYN_LPRELEASE,
	SYN_PAN, /* 0 left .. 1 right */
	SYN_DELAY, /* send level */
	SYN_DELAYTIME, /* seconds; < 0 keeps the current global value */
	SYN_DELAYFEEDBACK, /* 0..1; < 0 keeps */
	SYN_ROOM, /* reverb send level */
	SYN_ROOMSIZE, /* 0..1; < 0 keeps */
	SYN_FMI, /* FM modulation index */
	SYN_FMH, /* FM harmonicity ratio */
	SYN_VIB, /* vibrato Hz */
	SYN_VIBMOD, /* vibrato depth in semitones */
	SYN_SHAPE, /* waveshaper amount 0..1 */
	SYN_CRUSH, /* bit depth, <= 0 = off */
	SYN_NOISE, /* noise mixed into an oscillator, 0..1 */
	SYN_RESERVED,
	SYN_EVENT_FIELDS
};

enum {
	SYN_SRC_SINE,
	SYN_SRC_SAWTOOTH,
	SYN_SRC_SQUARE,
	SYN_SRC_TRIANGLE,
	SYN_SRC_WHITE,
	SYN_SRC_PINK,
	SYN_SRC_BROWN,
	SYN_SRC_BD = 16,
	SYN_SRC_SD,
	SYN_SRC_HH,
	SYN_SRC_OH,
	SYN_SRC_CP,
	SYN_SRC_RIM,
	SYN_SRC_LT,
	SYN_SRC_MT,
	SYN_SRC_HT,
	SYN_SRC_CR,
	SYN_SRC_RD
};

typedef struct Synth Synth;

/* Bytes to allocate for a Synth (it holds its delay and reverb lines). */
uint32_t syn_sizeof(void);
void syn_init(Synth *s, float sample_rate);
/* Drops every voice, queued event and effect tail; the clock restarts at 0. */
void syn_reset(Synth *s);
/* Queues `count` events. Events already in the past start immediately. */
void syn_schedule(Synth *s, const double *records, int count);
/* Renders `frames` stereo frames into out[2 * frames] and advances the clock. */
void syn_render(Synth *s, float *out, int frames);
/* Seconds rendered since init/reset. */
double syn_time(const Synth *s);
int syn_active_voices(const Synth *s);
int syn_pending_events(const Synth *s);
void syn_set_master_gain(Synth *s, float gain);

#ifdef __cplusplus
}
#endif

#endif
