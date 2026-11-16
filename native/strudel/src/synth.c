/* See synth.h. Freestanding C: no libc, no libm. */
#include "synth.h"

#define MAX_VOICES 64
#define MAX_EVENTS 2048
#define CHUNK 128 /* frames mixed per pass */
#define CTRL 16 /* samples between pitch / filter updates */
#define DELAY_FRAMES 131072 /* power of two, > 2 s at 48 kHz */
#define DELAY_MAX_SECONDS 2.0f
#define COMBS 4
#define ALLPASSES 2
#define COMB_FRAMES 4096
#define ALLPASS_FRAMES 2048
#define REVERB_REF_RATE 44100.0f /* the tunings below are in frames at this rate */
#define REVERB_STEREO_SPREAD 23
#define REVERB_INPUT_GAIN 0.06f
#define REVERB_DAMP 0.25f
#define REVERB_FEEDBACK_MIN 0.70f
#define REVERB_FEEDBACK_RANGE 0.28f
#define ALLPASS_FEEDBACK 0.5f
#define DEFAULT_DELAY_SECONDS 0.25f
#define DEFAULT_DELAY_FEEDBACK 0.5f
#define MAX_DELAY_FEEDBACK 0.95f
#define DEFAULT_ROOM_SIZE 0.5f
#define MIN_ENV_SECONDS 0.001f
#define DRUM_ATTACK_SECONDS 0.001f
#define DRUM_RELEASE_SECONDS 0.005f
#define DECAY_TAUS_TO_SILENCE 6.9f /* e^-6.9 = -60 dB */
#define MIN_CUTOFF 20.0f
#define MAX_CUTOFF_RATIO 0.45f /* of the sample rate */
#define SEMITONE_RATIO 0.059463f /* 2^(1/12) - 1 */
#define SOFT_CLIP_KNEE 0.7f
#define ANTI_DENORMAL 1e-20f
#define NOISE_SEED 0x9E3779B9u
#define PI 3.14159265358979f
#define TWO_PI 6.28318530717959f
#define INV_LN2 1.44269504f
#define LN2 0.69314718f
#define SRC_CLAP_BURST 64 /* internal: a later burst of SYN_SRC_CP; SYN_RESERVED = 1 for the tail */

static const int COMB_TUNING[COMBS] = { 1116, 1188, 1277, 1356 };
static const int ALLPASS_TUNING[ALLPASSES] = { 556, 441 };

typedef struct {
	int active;
	int wave;
	int32_t age, hold, release; /* samples */
	float freq, phase, dt, gain;
	float attack, decay, sustain; /* attack / decay in samples */
	int exp_env; /* drums: exponential decay instead of the ADSR */
	float exp_level, exp_coef;
	float pitch_oct, pitch_env, pitch_coef; /* pitch sweep, per CTRL step */
	float noise_mix;
	float fm_index, fm_ratio, fm_phase, fm_dt, fm_dev;
	float vib_dt, vib_depth, vib_phase;
	float cutoff, lp_k, lp_env, lp_attack, lp_decay, lp_sustain, lp_release;
	float lp_a1, lp_a2, lp_a3, lp_ic1, lp_ic2;
	float hcutoff, hp_k, hp_a1, hp_a2, hp_a3, hp_ic1, hp_ic2;
	float shape_k, crush_steps;
	float pan_l, pan_r, delay_send, room_send;
	float pink0, pink1, pink2, brown;
	uint32_t rng;
} Voice;

typedef struct {
	int64_t start; /* sample index */
	float f[SYN_EVENT_FIELDS];
} Event;

typedef struct {
	float buf[COMB_FRAMES];
	int len, pos;
	float store;
} Comb;

typedef struct {
	float buf[ALLPASS_FRAMES];
	int len, pos;
} Allpass;

struct Synth {
	float rate;
	float master_gain;
	int64_t now;
	uint32_t rng;
	Voice voices[MAX_VOICES];
	Event events[MAX_EVENTS];
	int event_count;
	float delay_l[DELAY_FRAMES], delay_r[DELAY_FRAMES];
	int delay_pos, delay_len;
	float delay_feedback;
	Comb combs[2][COMBS];
	Allpass allpasses[2][ALLPASSES];
	float comb_feedback;
};

/* ---- math without libm ---- */

static float f_floor(float x) {
	int32_t i = (int32_t)x;
	return (float)(i - (x < (float)i));
}

static float f_clamp(float x, float lo, float hi) {
	return x < lo ? lo : (x > hi ? hi : x);
}

/* sin(2 pi t) for t in [-0.5, 0.5]; error below 4e-6. */
static float sin_turn(float t) {
	if (t > 0.25f) {
		t = 0.5f - t;
	} else if (t < -0.25f) {
		t = -0.5f - t;
	}
	float x = t * TWO_PI;
	float x2 = x * x;
	return x * (1.0f + x2 * (-1.0f / 6.0f + x2 * (1.0f / 120.0f + x2 * (-1.0f / 5040.0f + x2 * (1.0f / 362880.0f)))));
}

static float sin_rad(float x) {
	float t = x * (1.0f / TWO_PI);
	return sin_turn(t - f_floor(t + 0.5f));
}

static float cos_rad(float x) {
	return sin_rad(x + PI * 0.5f);
}

/* 2^x; relative error below 2e-5. */
static float exp2_approx(float x) {
	x = f_clamp(x, -60.0f, 60.0f);
	float whole = f_floor(x);
	float y = (x - whole) * LN2;
	float frac = 1.0f + y * (1.0f + y * (0.5f + y * (1.0f / 6.0f + y * (1.0f / 24.0f + y * (1.0f / 120.0f + y * (1.0f / 720.0f))))));
	union {
		float f;
		uint32_t u;
	} scale;
	scale.u = (uint32_t)((int32_t)whole + 127) << 23;
	return frac * scale.f;
}

static uint32_t xorshift(uint32_t x) {
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	return x;
}

/* Each voice has its own generator, so the output does not depend on how
 * rendering is split into calls. */
static float noise(Voice *v) {
	v->rng = xorshift(v->rng);
	return (float)(int32_t)v->rng * (1.0f / 2147483648.0f);
}

static void zero(void *ptr, uint32_t bytes) {
	volatile unsigned char *p = (volatile unsigned char *)ptr; /* volatile: no memset call */
	while (bytes--) {
		*p++ = 0;
	}
}

/* ---- envelopes and filters ---- */

static float adsr(float age, float attack, float decay, float sustain) {
	if (age < attack) {
		return age / attack;
	}
	if (age < attack + decay) {
		return 1.0f - (1.0f - sustain) * (age - attack) / decay;
	}
	return sustain;
}

/* The ADSR while held, then a linear release from the level at note-off. */
static float envelope(int32_t age, int32_t hold, float attack, float decay, float sustain, float release) {
	if (age < hold) {
		return adsr((float)age, attack, decay, sustain);
	}
	float left = 1.0f - (float)(age - hold) / release;
	return left > 0.0f ? adsr((float)hold, attack, decay, sustain) * left : 0.0f;
}

/* State-variable filter coefficients (trapezoidal integration). */
static void svf_coefficients(float rate, float cutoff, float k, float *a1, float *a2, float *a3) {
	float turn = f_clamp(cutoff, MIN_CUTOFF, rate * MAX_CUTOFF_RATIO) / rate * 0.5f;
	float g = sin_turn(turn) / sin_turn(turn + 0.25f); /* tan(pi fc / rate) */
	*a1 = 1.0f / (1.0f + g * (g + k));
	*a2 = g * *a1;
	*a3 = g * *a2;
}

static float poly_blep(float t, float dt) {
	if (dt <= 0.0f) {
		return 0.0f;
	}
	if (t < dt) {
		t /= dt;
		return t + t - t * t - 1.0f;
	}
	if (t > 1.0f - dt) {
		t = (t - 1.0f) / dt;
		return t * t + t + t + 1.0f;
	}
	return 0.0f;
}

/* ---- voices ---- */

static Voice *allocate_voice(Synth *s) {
	Voice *oldest = &s->voices[0];
	for (int i = 0; i < MAX_VOICES; i++) {
		Voice *v = &s->voices[i];
		if (!v->active) {
			return v;
		}
		if (v->age > oldest->age) {
			oldest = v;
		}
	}
	return oldest;
}

static float seconds_to_samples(const Synth *s, float seconds) {
	return (seconds > MIN_ENV_SECONDS ? seconds : MIN_ENV_SECONDS) * s->rate;
}

/* Per-sample multiplier that decays by 1/e every `tau` seconds. */
static float decay_coef(const Synth *s, float tau, int samples_per_step) {
	return exp2_approx(-INV_LN2 * (float)samples_per_step / (tau * s->rate));
}

/* Starts a voice from event fields. exp_tau > 0 selects a drum-style
 * exponential decay; pitch_oct sweeps the pitch down from that many octaves
 * above freq with time constant pitch_tau. */
static void start_voice(Synth *s, const float *f, int wave, float exp_tau, float pitch_oct, float pitch_tau) {
	Voice *v = allocate_voice(s);
	zero(v, sizeof(Voice));
	v->active = 1;
	s->rng = xorshift(s->rng);
	v->rng = s->rng;
	v->wave = wave;
	v->freq = f[SYN_FREQ];
	v->gain = f[SYN_GAIN];
	v->noise_mix = f_clamp(f[SYN_NOISE], 0.0f, 1.0f);
	if (exp_tau > 0.0f) {
		v->exp_env = 1;
		v->exp_level = 1.0f;
		v->exp_coef = decay_coef(s, exp_tau, 1);
		v->attack = seconds_to_samples(s, DRUM_ATTACK_SECONDS);
		v->hold = (int32_t)(exp_tau * DECAY_TAUS_TO_SILENCE * s->rate);
		v->release = (int32_t)seconds_to_samples(s, DRUM_RELEASE_SECONDS);
	} else {
		v->attack = seconds_to_samples(s, f[SYN_ATTACK]);
		v->decay = seconds_to_samples(s, f[SYN_DECAY]);
		v->sustain = f_clamp(f[SYN_SUSTAIN], 0.0f, 1.0f);
		v->hold = (int32_t)seconds_to_samples(s, f[SYN_DURATION]);
		v->release = (int32_t)seconds_to_samples(s, f[SYN_RELEASE]);
	}
	if (pitch_oct != 0.0f) {
		v->pitch_oct = pitch_oct;
		v->pitch_env = 1.0f;
		v->pitch_coef = decay_coef(s, pitch_tau, CTRL);
	}
	if (f[SYN_FMI] != 0.0f) {
		v->fm_index = f[SYN_FMI];
		v->fm_ratio = f[SYN_FMH] > 0.0f ? f[SYN_FMH] : 1.0f;
	}
	if (f[SYN_VIB] > 0.0f && f[SYN_VIBMOD] != 0.0f) {
		v->vib_dt = f[SYN_VIB] * (float)CTRL / s->rate;
		v->vib_depth = f[SYN_VIBMOD] * SEMITONE_RATIO;
	}
	if (f[SYN_CUTOFF] > 0.0f) {
		v->cutoff = f[SYN_CUTOFF];
		v->lp_k = 1.0f / (f[SYN_RESONANCE] > 0.05f ? f[SYN_RESONANCE] : 0.05f);
		v->lp_env = f[SYN_LPENV];
		v->lp_attack = seconds_to_samples(s, f[SYN_LPATTACK]);
		v->lp_decay = seconds_to_samples(s, f[SYN_LPDECAY]);
		v->lp_sustain = f_clamp(f[SYN_LPSUSTAIN], 0.0f, 1.0f);
		v->lp_release = seconds_to_samples(s, f[SYN_LPRELEASE]);
	}
	if (f[SYN_HCUTOFF] > 0.0f) {
		v->hcutoff = f[SYN_HCUTOFF];
		v->hp_k = 1.0f / (f[SYN_HRESONANCE] > 0.05f ? f[SYN_HRESONANCE] : 0.05f);
		svf_coefficients(s->rate, v->hcutoff, v->hp_k, &v->hp_a1, &v->hp_a2, &v->hp_a3);
	}
	float shape = f_clamp(f[SYN_SHAPE], 0.0f, 0.99f);
	v->shape_k = shape > 0.0f ? 2.0f * shape / (1.0f - shape) : 0.0f;
	v->crush_steps = f[SYN_CRUSH] > 0.0f ? exp2_approx(f_clamp(f[SYN_CRUSH], 1.0f, 16.0f) - 1.0f) : 0.0f;
	float pan = f_clamp(f[SYN_PAN], 0.0f, 1.0f);
	v->pan_l = cos_rad(pan * PI * 0.5f);
	v->pan_r = sin_rad(pan * PI * 0.5f);
	v->delay_send = f[SYN_DELAY] > 0.0f ? f[SYN_DELAY] : 0.0f;
	v->room_send = f[SYN_ROOM] > 0.0f ? f[SYN_ROOM] : 0.0f;
}

static void copy_fields(float *to, const float *from) {
	for (int i = 0; i < SYN_EVENT_FIELDS; i++) {
		to[i] = from[i];
	}
}

/* One synthesized drum layer: `level` scales the event gain; a filter the
 * event already asks for wins over the layer's own. */
static void drum_layer(Synth *s, const float *event, int wave, float freq, float level, float tau,
		float pitch_oct, float pitch_tau, float lowpass, float highpass) {
	float f[SYN_EVENT_FIELDS];
	copy_fields(f, event);
	f[SYN_FREQ] = freq;
	f[SYN_GAIN] = event[SYN_GAIN] * level;
	f[SYN_FMI] = 0.0f;
	f[SYN_VIB] = 0.0f;
	f[SYN_NOISE] = 0.0f;
	f[SYN_LPENV] = 0.0f;
	if (f[SYN_CUTOFF] <= 0.0f && lowpass > 0.0f) {
		f[SYN_CUTOFF] = lowpass;
		f[SYN_RESONANCE] = 0.7f;
	}
	if (f[SYN_HCUTOFF] <= 0.0f && highpass > 0.0f) {
		f[SYN_HCUTOFF] = highpass;
		f[SYN_HRESONANCE] = 0.7f;
	}
	start_voice(s, f, wave, tau, pitch_oct, pitch_tau);
}

/* A drum layer that starts `delay` seconds late (clap bursts): queued again. */
static void queue_event(Synth *s, int64_t start, const float *f) {
	if (s->event_count >= MAX_EVENTS) {
		return;
	}
	Event *e = &s->events[s->event_count++];
	e->start = start;
	copy_fields(e->f, f);
}

static void start_event(Synth *s, const float *f) {
	int source = (int)f[SYN_SOURCE];
	if (f[SYN_DELAY] > 0.0f) {
		if (f[SYN_DELAYTIME] >= 0.0f) {
			float seconds = f_clamp(f[SYN_DELAYTIME], 0.0f, DELAY_MAX_SECONDS);
			int len = (int)(seconds * s->rate);
			s->delay_len = len < 1 ? 1 : (len > DELAY_FRAMES - 1 ? DELAY_FRAMES - 1 : len);
		}
		if (f[SYN_DELAYFEEDBACK] >= 0.0f) {
			s->delay_feedback = f_clamp(f[SYN_DELAYFEEDBACK], 0.0f, MAX_DELAY_FEEDBACK);
		}
	}
	if (f[SYN_ROOM] > 0.0f && f[SYN_ROOMSIZE] >= 0.0f) {
		s->comb_feedback = REVERB_FEEDBACK_MIN + REVERB_FEEDBACK_RANGE * f_clamp(f[SYN_ROOMSIZE], 0.0f, 1.0f);
	}
	switch (source) {
		case SYN_SRC_BD:
			drum_layer(s, f, SYN_SRC_SINE, 48.0f, 1.0f, 0.11f, 2.3f, 0.03f, 0.0f, 0.0f);
			break;
		case SYN_SRC_SD:
			drum_layer(s, f, SYN_SRC_SINE, 180.0f, 0.7f, 0.05f, 0.8f, 0.02f, 0.0f, 0.0f);
			drum_layer(s, f, SYN_SRC_WHITE, 0.0f, 0.75f, 0.06f, 0.0f, 0.0f, 9000.0f, 1400.0f);
			break;
		case SYN_SRC_HH:
			drum_layer(s, f, SYN_SRC_WHITE, 0.0f, 0.45f, 0.014f, 0.0f, 0.0f, 0.0f, 7000.0f);
			break;
		case SYN_SRC_OH:
			drum_layer(s, f, SYN_SRC_WHITE, 0.0f, 0.4f, 0.09f, 0.0f, 0.0f, 0.0f, 6500.0f);
			break;
		case SYN_SRC_CP: {
			/* Three short bursts 10 ms apart, then the tail. */
			float burst[SYN_EVENT_FIELDS];
			copy_fields(burst, f);
			burst[SYN_SOURCE] = (float)SRC_CLAP_BURST;
			drum_layer(s, f, SYN_SRC_WHITE, 0.0f, 0.7f, 0.004f, 0.0f, 0.0f, 3200.0f, 900.0f);
			queue_event(s, s->now + (int64_t)(0.010f * s->rate), burst);
			burst[SYN_RESERVED] = 1.0f;
			queue_event(s, s->now + (int64_t)(0.020f * s->rate), burst);
			break;
		}
		case SRC_CLAP_BURST:
			drum_layer(s, f, SYN_SRC_WHITE, 0.0f, 0.7f, f[SYN_RESERVED] > 0.0f ? 0.055f : 0.004f,
					0.0f, 0.0f, 3200.0f, 900.0f);
			break;
		case SYN_SRC_RIM:
			drum_layer(s, f, SYN_SRC_SINE, 1700.0f, 0.6f, 0.008f, 0.0f, 0.0f, 0.0f, 0.0f);
			drum_layer(s, f, SYN_SRC_WHITE, 0.0f, 0.4f, 0.004f, 0.0f, 0.0f, 0.0f, 3000.0f);
			break;
		case SYN_SRC_LT:
			drum_layer(s, f, SYN_SRC_SINE, 90.0f, 0.8f, 0.10f, 0.7f, 0.05f, 0.0f, 0.0f);
			break;
		case SYN_SRC_MT:
			drum_layer(s, f, SYN_SRC_SINE, 130.0f, 0.8f, 0.09f, 0.7f, 0.05f, 0.0f, 0.0f);
			break;
		case SYN_SRC_HT:
			drum_layer(s, f, SYN_SRC_SINE, 180.0f, 0.8f, 0.08f, 0.7f, 0.05f, 0.0f, 0.0f);
			break;
		case SYN_SRC_CR:
			drum_layer(s, f, SYN_SRC_WHITE, 0.0f, 0.4f, 0.28f, 0.0f, 0.0f, 0.0f, 5000.0f);
			break;
		case SYN_SRC_RD:
			drum_layer(s, f, SYN_SRC_WHITE, 0.0f, 0.3f, 0.16f, 0.0f, 0.0f, 0.0f, 6500.0f);
			break;
		default:
			if (source >= SYN_SRC_SINE && source <= SYN_SRC_BROWN && (f[SYN_FREQ] > 0.0f || source >= SYN_SRC_WHITE)) {
				start_voice(s, f, source, 0.0f, 0.0f, 0.0f);
			}
			break;
	}
}

static void voice_control(const Synth *s, Voice *v) {
	float freq = v->freq;
	if (v->pitch_oct != 0.0f) {
		freq *= exp2_approx(v->pitch_oct * v->pitch_env);
		v->pitch_env *= v->pitch_coef;
	}
	if (v->vib_depth != 0.0f) {
		freq *= 1.0f + v->vib_depth * sin_turn(v->vib_phase - 0.5f);
		v->vib_phase += v->vib_dt;
		v->vib_phase -= f_floor(v->vib_phase);
	}
	v->dt = freq / s->rate;
	if (v->fm_index != 0.0f) {
		v->fm_dt = v->dt * v->fm_ratio;
		v->fm_dev = v->fm_index * v->fm_dt;
	}
	if (v->cutoff > 0.0f) {
		float cutoff = v->cutoff;
		if (v->lp_env != 0.0f) {
			cutoff *= exp2_approx(v->lp_env * envelope(v->age, v->hold, v->lp_attack, v->lp_decay, v->lp_sustain, v->lp_release));
		}
		svf_coefficients(s->rate, cutoff, v->lp_k, &v->lp_a1, &v->lp_a2, &v->lp_a3);
	}
}

static float oscillator(Voice *v) {
	float inc = v->dt;
	if (v->fm_index != 0.0f) {
		inc += v->fm_dev * sin_turn(v->fm_phase - 0.5f);
		v->fm_phase += v->fm_dt;
		v->fm_phase -= f_floor(v->fm_phase);
	}
	v->phase += inc;
	v->phase -= f_floor(v->phase);
	float p = v->phase;
	switch (v->wave) {
		case SYN_SRC_SINE:
			return -sin_turn(p - 0.5f);
		case SYN_SRC_SAWTOOTH:
			return 2.0f * p - 1.0f - poly_blep(p, inc);
		case SYN_SRC_SQUARE: {
			float half = p + 0.5f;
			half -= f_floor(half);
			return (p < 0.5f ? 1.0f : -1.0f) + poly_blep(p, inc) - poly_blep(half, inc);
		}
		case SYN_SRC_TRIANGLE:
			return 1.0f - 4.0f * (p < 0.5f ? p : 1.0f - p);
		case SYN_SRC_PINK: {
			float w = noise(v);
			v->pink0 = 0.99765f * v->pink0 + w * 0.0990460f;
			v->pink1 = 0.96300f * v->pink1 + w * 0.2965164f;
			v->pink2 = 0.57000f * v->pink2 + w * 1.0526913f;
			return (v->pink0 + v->pink1 + v->pink2 + w * 0.1848f) * 0.2f;
		}
		case SYN_SRC_BROWN:
			v->brown = (v->brown + 0.02f * noise(v)) / 1.02f;
			return v->brown * 3.5f;
		default:
			return noise(v);
	}
}

/* Mixes up to CHUNK frames of one voice into the dry and send buses. */
static void render_voice(Synth *s, Voice *v, float *dry, float *delay_bus, float *room_bus, int frames) {
	int32_t total = v->hold + v->release;
	for (int i = 0; i < frames; i++) {
		if (v->age >= total) {
			v->active = 0;
			return;
		}
		if (v->age % CTRL == 0) {
			voice_control(s, v);
		}
		float x = oscillator(v);
		if (v->noise_mix > 0.0f) {
			x = x * (1.0f - v->noise_mix) + noise(v) * v->noise_mix;
		}
		if (v->cutoff > 0.0f) {
			float v3 = x - v->lp_ic2;
			float v1 = v->lp_a1 * v->lp_ic1 + v->lp_a2 * v3;
			float v2 = v->lp_ic2 + v->lp_a2 * v->lp_ic1 + v->lp_a3 * v3;
			v->lp_ic1 = 2.0f * v1 - v->lp_ic1 + ANTI_DENORMAL;
			v->lp_ic2 = 2.0f * v2 - v->lp_ic2;
			x = v2;
		}
		if (v->hcutoff > 0.0f) {
			float v3 = x - v->hp_ic2;
			float v1 = v->hp_a1 * v->hp_ic1 + v->hp_a2 * v3;
			float v2 = v->hp_ic2 + v->hp_a2 * v->hp_ic1 + v->hp_a3 * v3;
			v->hp_ic1 = 2.0f * v1 - v->hp_ic1 + ANTI_DENORMAL;
			v->hp_ic2 = 2.0f * v2 - v->hp_ic2;
			x = x - v->hp_k * v1 - v2;
		}
		if (v->shape_k > 0.0f) {
			x = (1.0f + v->shape_k) * x / (1.0f + v->shape_k * (x < 0.0f ? -x : x));
		}
		if (v->crush_steps > 0.0f) {
			x = f_floor(x * v->crush_steps + 0.5f) / v->crush_steps;
		}
		float env;
		if (v->exp_env) {
			float age = (float)v->age;
			env = v->exp_level * (age < v->attack ? age / v->attack : 1.0f);
			v->exp_level *= v->exp_coef;
			if (v->age >= v->hold) {
				env *= 1.0f - (float)(v->age - v->hold) / (float)v->release;
			}
		} else {
			env = envelope(v->age, v->hold, v->attack, v->decay, v->sustain, (float)v->release);
		}
		x *= env * v->gain;
		float l = x * v->pan_l;
		float r = x * v->pan_r;
		dry[2 * i] += l;
		dry[2 * i + 1] += r;
		if (v->delay_send > 0.0f) {
			delay_bus[2 * i] += l * v->delay_send;
			delay_bus[2 * i + 1] += r * v->delay_send;
		}
		if (v->room_send > 0.0f) {
			room_bus[2 * i] += l * v->room_send;
			room_bus[2 * i + 1] += r * v->room_send;
		}
		v->age++;
	}
}

/* ---- effects ---- */

static float comb_tick(Comb *c, float in, float feedback) {
	float out = c->buf[c->pos];
	c->store = out * (1.0f - REVERB_DAMP) + c->store * REVERB_DAMP + ANTI_DENORMAL;
	c->buf[c->pos] = in + c->store * feedback;
	if (++c->pos >= c->len) {
		c->pos = 0;
	}
	return out;
}

static float allpass_tick(Allpass *a, float in) {
	float delayed = a->buf[a->pos];
	a->buf[a->pos] = in + delayed * ALLPASS_FEEDBACK;
	if (++a->pos >= a->len) {
		a->pos = 0;
	}
	return delayed - in;
}

static float soft_clip(float x) {
	float mag = x < 0.0f ? -x : x;
	if (mag <= SOFT_CLIP_KNEE) {
		return x;
	}
	float over = (mag - SOFT_CLIP_KNEE) / (1.0f - SOFT_CLIP_KNEE);
	float out = SOFT_CLIP_KNEE + (1.0f - SOFT_CLIP_KNEE) * over / (1.0f + over);
	return x < 0.0f ? -out : out;
}

static void render_chunk(Synth *s, float *out, int frames) {
	float dry[2 * CHUNK], delay_bus[2 * CHUNK], room_bus[2 * CHUNK];
	for (int i = 0; i < 2 * frames; i++) {
		dry[i] = 0.0f;
		delay_bus[i] = 0.0f;
		room_bus[i] = 0.0f;
	}
	for (int i = 0; i < MAX_VOICES; i++) {
		if (s->voices[i].active) {
			render_voice(s, &s->voices[i], dry, delay_bus, room_bus, frames);
		}
	}
	for (int i = 0; i < frames; i++) {
		int read = (s->delay_pos - s->delay_len) & (DELAY_FRAMES - 1);
		float dl = s->delay_l[read];
		float dr = s->delay_r[read];
		s->delay_l[s->delay_pos] = delay_bus[2 * i] + dl * s->delay_feedback + ANTI_DENORMAL;
		s->delay_r[s->delay_pos] = delay_bus[2 * i + 1] + dr * s->delay_feedback + ANTI_DENORMAL;
		s->delay_pos = (s->delay_pos + 1) & (DELAY_FRAMES - 1);

		float in = (room_bus[2 * i] + room_bus[2 * i + 1]) * REVERB_INPUT_GAIN;
		float wet[2] = { 0.0f, 0.0f };
		for (int ch = 0; ch < 2; ch++) {
			for (int c = 0; c < COMBS; c++) {
				wet[ch] += comb_tick(&s->combs[ch][c], in, s->comb_feedback);
			}
			for (int a = 0; a < ALLPASSES; a++) {
				wet[ch] = allpass_tick(&s->allpasses[ch][a], wet[ch]);
			}
		}
		out[2 * i] = soft_clip((dry[2 * i] + dl + wet[0]) * s->master_gain);
		out[2 * i + 1] = soft_clip((dry[2 * i + 1] + dr + wet[1]) * s->master_gain);
	}
}

/* ---- public ---- */

uint32_t syn_sizeof(void) {
	return (uint32_t)sizeof(Synth);
}

void syn_reset(Synth *s) {
	float rate = s->rate;
	float master = s->master_gain;
	zero(s, sizeof(Synth));
	s->rate = rate;
	s->master_gain = master;
	s->rng = NOISE_SEED;
	s->delay_len = (int)(DEFAULT_DELAY_SECONDS * rate);
	s->delay_feedback = DEFAULT_DELAY_FEEDBACK;
	s->comb_feedback = REVERB_FEEDBACK_MIN + REVERB_FEEDBACK_RANGE * DEFAULT_ROOM_SIZE;
	float scale = rate / REVERB_REF_RATE;
	for (int ch = 0; ch < 2; ch++) {
		for (int c = 0; c < COMBS; c++) {
			int len = (int)((float)(COMB_TUNING[c] + ch * REVERB_STEREO_SPREAD) * scale);
			s->combs[ch][c].len = len < COMB_FRAMES ? len : COMB_FRAMES;
		}
		for (int a = 0; a < ALLPASSES; a++) {
			int len = (int)((float)(ALLPASS_TUNING[a] + ch * REVERB_STEREO_SPREAD) * scale);
			s->allpasses[ch][a].len = len < ALLPASS_FRAMES ? len : ALLPASS_FRAMES;
		}
	}
}

void syn_init(Synth *s, float sample_rate) {
	s->rate = sample_rate > 8000.0f ? sample_rate : 8000.0f;
	s->master_gain = 1.0f;
	syn_reset(s);
}

void syn_set_master_gain(Synth *s, float gain) {
	s->master_gain = gain;
}

void syn_schedule(Synth *s, const double *records, int count) {
	for (int n = 0; n < count; n++) {
		const double *r = records + (long)n * SYN_EVENT_FIELDS;
		float f[SYN_EVENT_FIELDS];
		for (int i = 0; i < SYN_EVENT_FIELDS; i++) {
			f[i] = (float)r[i];
		}
		f[SYN_RESERVED] = 0.0f;
		if (f[SYN_SOURCE] == (float)SRC_CLAP_BURST) {
			continue;
		}
		queue_event(s, (int64_t)(r[SYN_START] * (double)s->rate), f);
	}
}

void syn_render(Synth *s, float *out, int frames) {
	while (frames > 0) {
		int64_t next = s->now + CHUNK;
		for (int i = 0; i < s->event_count; i++) {
			Event *e = &s->events[i];
			if (e->start <= s->now) {
				float f[SYN_EVENT_FIELDS];
				copy_fields(f, e->f);
				*e = s->events[--s->event_count];
				i--;
				start_event(s, f);
			} else if (e->start < next) {
				next = e->start;
			}
		}
		int span = (int)(next - s->now);
		if (span > frames) {
			span = frames;
		}
		render_chunk(s, out, span);
		out += 2 * span;
		s->now += span;
		frames -= span;
	}
}

double syn_time(const Synth *s) {
	return (double)s->now / (double)s->rate;
}

int syn_active_voices(const Synth *s) {
	int count = 0;
	for (int i = 0; i < MAX_VOICES; i++) {
		count += s->voices[i].active;
	}
	return count;
}

int syn_pending_events(const Synth *s) {
	return s->event_count;
}
