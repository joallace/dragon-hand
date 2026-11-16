// Music host glue, bundled with Strudel's pattern engine into
// presentation/audio/music/strudel_bundle.mjs (npm run build). The bundle
// runs in JsRuntime on desktop and in the browser on web. It evaluates song
// code the way strudel.cc does (Strudel's own repl and transpiler) and turns
// the events of a time window into flat records for the synth
// (native/strudel/src/synth.h: the F and SRC tables below mirror its enums).
//
// Globals for the host:
//   music_load(code)  -> { cps, warnings } ; throws on a bad song and keeps
//                        the previous one
//   music_query(begin_cycle, end_cycle, begin_seconds)
//                     -> flat array, FIELDS numbers per event
//   music_fields()    -> FIELDS
import './shim.mjs';
import * as core from '@strudel/core';
import * as mini from '@strudel/mini';
import * as tonal from '@strudel/tonal';
import { transpiler } from '@strudel/transpiler';

const F = {
  START: 0, DURATION: 1, SOURCE: 2, FREQ: 3, GAIN: 4, ATTACK: 5, DECAY: 6, SUSTAIN: 7, RELEASE: 8,
  CUTOFF: 9, RESONANCE: 10, HCUTOFF: 11, HRESONANCE: 12, LPENV: 13, LPATTACK: 14, LPDECAY: 15,
  LPSUSTAIN: 16, LPRELEASE: 17, PAN: 18, DELAY: 19, DELAYTIME: 20, DELAYFEEDBACK: 21, ROOM: 22,
  ROOMSIZE: 23, FMI: 24, FMH: 25, VIB: 26, VIBMOD: 27, SHAPE: 28, CRUSH: 29, NOISE: 30,
};
const FIELDS = 32;

const SRC = {
  sine: 0, sin: 0, sawtooth: 1, saw: 1, square: 2, sqr: 2, pulse: 2, triangle: 3, tri: 3,
  white: 4, noise: 4, pink: 5, brown: 6,
  bd: 16, sd: 17, sn: 17, hh: 18, ch: 18, oh: 19, cp: 20, rim: 21, rs: 21,
  lt: 22, mt: 23, ht: 24, cr: 25, cy: 25, rd: 26,
};
const FIRST_DRUM = SRC.bd;

// Strudel's own defaults (superdough), so pasted songs sit at a similar level.
const DEFAULT_CPS = 0.5;
const DEFAULT_SOURCE = 'triangle';
const DEFAULT_NOTE = 36;
const DEFAULT_GAIN = 0.8;
const OSCILLATOR_LEVEL = 0.3;
const AMP_ENVELOPE = [0.001, 0.05, 0.6, 0.01];
const FILTER_ENVELOPE = [0.005, 0.14, 0, 0.1];
const ENVELOPE_MIN = 0.001;
const RELEASE_MIN = 0.01;
const DEFAULT_RESONANCE_DB = 1;
const DEFAULT_PAN = 0.5;
const DEFAULT_VIBMOD = 0.5;
const ROOM_SIZE_FULL = 8; // Strudel room sizes run in seconds; the synth takes 0..1
const KEEP = -1; // "leave the global effect setting alone"

let pattern = core.silence;
let cps = DEFAULT_CPS;
let unknownSources = new Set();

const number = (value, fallback) => (typeof value === 'number' && Number.isFinite(value) ? value : fallback);

// Envelope defaults the way Strudel fills them in: all unset -> the preset;
// otherwise a missing sustain is full unless a decay was given.
function envelope(a, d, s, r, preset) {
  if (a == null && d == null && s == null && r == null) return preset;
  const sustain = s != null ? s : (a != null && d == null) || (a == null && d == null) ? 1 : ENVELOPE_MIN;
  return [Math.max(a ?? 0, ENVELOPE_MIN), Math.max(d ?? 0, ENVELOPE_MIN), Math.min(sustain, 1), Math.max(r ?? 0, RELEASE_MIN)];
}

function frequency(value) {
  if (typeof value.freq === 'number') return value.freq;
  let note = value.note ?? value.n ?? DEFAULT_NOTE;
  if (typeof note === 'string') note = core.noteToMidi(note);
  return typeof note === 'number' ? core.midiToFreq(note) : 0;
}

const decibels = (db) => Math.pow(10, db / 20);

function record(out, hap, start, duration) {
  const value = hap.value;
  if (value == null || typeof value !== 'object') return;
  const name = String(value.s ?? DEFAULT_SOURCE).split(':')[0].toLowerCase();
  const source = SRC[name];
  if (source === undefined) {
    unknownSources.add(name);
    return;
  }
  const drum = source >= FIRST_DRUM;
  const base = out.length;
  for (let i = 0; i < FIELDS; i++) out.push(0);
  const amp = envelope(value.attack, value.decay, value.sustain, value.release, AMP_ENVELOPE);
  const anyFilterEnv = [value.lpattack, value.lpdecay, value.lpsustain, value.lprelease].some((x) => x != null);
  const filter = envelope(value.lpattack, value.lpdecay, value.lpsustain, value.lprelease, FILTER_ENVELOPE);
  const hold = duration * number(value.clip ?? value.legato, 1);
  out[base + F.START] = start;
  out[base + F.DURATION] = hold;
  out[base + F.SOURCE] = source;
  out[base + F.FREQ] = drum ? 0 : frequency(value);
  out[base + F.GAIN] = number(value.gain, DEFAULT_GAIN) * number(value.velocity, 1) * number(value.postgain, 1)
    * (drum ? 1 : OSCILLATOR_LEVEL);
  out[base + F.ATTACK] = amp[0];
  out[base + F.DECAY] = amp[1];
  out[base + F.SUSTAIN] = amp[2];
  out[base + F.RELEASE] = amp[3];
  out[base + F.CUTOFF] = number(value.cutoff, 0);
  out[base + F.RESONANCE] = decibels(number(value.resonance, DEFAULT_RESONANCE_DB));
  out[base + F.HCUTOFF] = number(value.hcutoff, 0);
  out[base + F.HRESONANCE] = decibels(number(value.hresonance, DEFAULT_RESONANCE_DB));
  out[base + F.LPENV] = number(value.lpenv, anyFilterEnv ? 1 : 0);
  out[base + F.LPATTACK] = filter[0];
  out[base + F.LPDECAY] = filter[1];
  out[base + F.LPSUSTAIN] = filter[2];
  out[base + F.LPRELEASE] = filter[3];
  out[base + F.PAN] = number(value.pan, DEFAULT_PAN);
  out[base + F.DELAY] = number(value.delay, 0);
  out[base + F.DELAYTIME] = number(value.delaytime, KEEP);
  out[base + F.DELAYFEEDBACK] = number(value.delayfeedback, KEEP);
  out[base + F.ROOM] = number(value.room, 0);
  const size = number(value.roomsize ?? value.size, KEEP);
  out[base + F.ROOMSIZE] = size < 0 ? KEEP : Math.min(size / ROOM_SIZE_FULL, 1);
  out[base + F.FMI] = number(value.fmi, 0);
  out[base + F.FMH] = number(value.fmh, 1);
  out[base + F.VIB] = number(value.vib, 0);
  out[base + F.VIBMOD] = number(value.vibmod, DEFAULT_VIBMOD);
  const distort = number(value.distort, 0);
  out[base + F.SHAPE] = number(value.shape, distort > 0 ? distort / (1 + distort) : 0);
  out[base + F.CRUSH] = number(value.crush, 0);
  out[base + F.NOISE] = number(value.noise, 0);
}

// Strudel's REPL, used only to evaluate: it gives songs `$:` lines, all(),
// hush(), setcpm() and friends. Its scheduler is never started; the game
// schedules from music_query().
let evalError = null;
const strudel = core.repl({
  defaultOutput: () => {},
  getTime: () => 0,
  transpiler,
  onEvalError: (error) => { evalError = error; },
});
await core.evalScope(core, mini, tonal, {
  samples: () => {}, // synths only: sample packs are ignored
});

globalThis.music_fields = () => FIELDS;

globalThis.music_load = async (code) => {
  evalError = null;
  strudel.setCps(DEFAULT_CPS); // each song starts from Strudel's default tempo
  const evaluated = await strudel.evaluate(code, false);
  if (evalError) throw evalError;
  if (!evaluated || typeof evaluated.queryArc !== 'function') {
    throw new Error('the song did not evaluate to a pattern');
  }
  evaluated.queryArc(0, 1); // a song that cannot be queried fails here, before it replaces the old one
  const songCps = strudel.scheduler.cps;
  pattern = evaluated;
  cps = songCps > 0 && Number.isFinite(songCps) ? songCps : DEFAULT_CPS;
  unknownSources = new Set();
  music_query(0, 1, 0); // collects unknown sound names from the first cycle
  return { cps, warnings: [...unknownSources].map((name) => `unknown sound "${name}"`) };
};

globalThis.music_query = (beginCycle, endCycle, beginSeconds) => {
  const out = [];
  for (const hap of pattern.queryArc(beginCycle, endCycle)) {
    if (!hap.hasOnset()) continue;
    const begin = hap.whole.begin.valueOf();
    const duration = (hap.whole.end.valueOf() - begin) / cps;
    record(out, hap, beginSeconds + (begin - beginCycle) / cps, duration);
  }
  return out;
};
