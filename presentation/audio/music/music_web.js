// Web music backend, evaluated in the page by WebMusicEngine (see
// web_music_engine.gd). Defines window.GHMusic, a table of engines: create()
// returns an id that every other call takes, so engines never share state.
//
// - Synth: native/strudel/src/synth.c as WebAssembly (synth.wasm), one
//   instance per engine, on the main thread (render() is cheap).
// - Songs: each one gets its own module Worker that imports the Strudel
//   bundle, so songs are isolated from the page and from each other, and one
//   that hangs or misbehaves is terminated. A new song replaces the playing
//   one only once it has loaded.
// - Scheduling mirrors StrudelEngine._schedule_ahead (strudel_engine.gd):
//   slices of a cycle are queried `lookahead` seconds ahead of the synth
//   clock; here the queries are messages, answered between frames. tick()
//   (once per game frame) schedules and reports, independently of render(),
//   so a song's result arrives even while the page's audio is suspended
//   (browsers start it only after the first click or key press).
//
// Song code is untrusted. Everything a worker sends is checked: only the
// reply that is due is accepted, anything else gets the worker terminated.
// Workers have no DOM; their network and storage APIs are removed before a
// song runs (best effort: a worker cannot be fully sandboxed).
(() => {
  'use strict';
  if (globalThis.GHMusic) return;

  const MAX_BATCHES_PER_REPLY = 4; // of the synth's event buffer
  const BAD_SONG = 'the song stopped responding';
  // A worker's messages are untrusted: what is passed on is bounded.
  const MAX_WARNINGS = 16;
  const MAX_MESSAGE_CHARS = 500;
  const clip = (text) => String(text ?? '').slice(0, MAX_MESSAGE_CHARS);
  // Taken away from a song's worker once the bundle is imported.
  const WORKER_BLOCKED = [
    'fetch', 'XMLHttpRequest', 'WebSocket', 'WebTransport', 'EventSource', 'importScripts',
    'Worker', 'SharedWorker', 'BroadcastChannel', 'indexedDB', 'caches',
  ];

  // What runs in each song's worker. The host functions are captured before
  // any song code runs, and the listener cannot be replaced by a song.
  const workerSource = (bundleUrl) => `
    import ${JSON.stringify(bundleUrl)};
    const load = globalThis.music_load;
    const query = globalThis.music_query;
    const fields = globalThis.music_fields();
    const post = globalThis.postMessage.bind(globalThis);
    for (const name of ${JSON.stringify(WORKER_BLOCKED)}) {
      try {
        Object.defineProperty(globalThis, name, { value: undefined, writable: false, configurable: false });
      } catch (error) {}
    }
    addEventListener('message', async (event) => {
      const m = event.data;
      if (m.type === 'load') {
        try {
          const info = await load(m.code);
          post({ type: 'loaded', ok: true, cps: Number(info.cps), warnings: [...info.warnings].map(String) });
        } catch (error) {
          post({ type: 'loaded', ok: false, error: String(error?.message ?? error) });
        }
      } else if (m.type === 'query') {
        let records;
        try {
          records = Float64Array.from(query(m.begin, m.end, m.seconds, m.cps));
        } catch (error) {
          records = new Float64Array(0);
        }
        post({ type: 'events', epoch: m.epoch, records }, [records.buffer]);
      }
    });
    post({ type: 'ready', fields });
  `;

  // Shared by every engine: the worker script (by bundle text) and the
  // compiled synth module (by its base64 text).
  let workerUrl = '';
  let workerBundle = null;
  let synthModule = null;
  let synthBase64 = null;

  let bundleUrl = '';

  function workerUrlFor(bundleText) {
    if (bundleText !== workerBundle) {
      // Running workers keep what they already imported.
      if (workerUrl) URL.revokeObjectURL(workerUrl);
      if (bundleUrl) URL.revokeObjectURL(bundleUrl);
      const blob = (text) => URL.createObjectURL(new Blob([text], { type: 'text/javascript' }));
      bundleUrl = blob(bundleText);
      workerUrl = blob(workerSource(bundleUrl));
      workerBundle = bundleText;
    }
    return workerUrl;
  }

  function synthModuleFor(wasmBase64) {
    if (wasmBase64 !== synthBase64) {
      synthBase64 = wasmBase64;
      synthModule = Promise.resolve()
        .then(() => WebAssembly.compile(Uint8Array.from(atob(wasmBase64), (c) => c.charCodeAt(0))))
        .catch((error) => {
          // Not cached: the next engine tries again.
          if (synthBase64 === wasmBase64) synthBase64 = null;
          throw error;
        });
    }
    return synthModule;
  }

  class Engine {
    constructor(bundleText, wasmBase64, config) {
      this.config = config;
      this.workerUrl = workerUrlFor(bundleText);
      this.synth = null; // WebAssembly exports
      this.fields = 0;
      this.ready = false;
      this.broken = ''; // why the synth could not start
      this.closed = false;
      this.waitingCode = null; // load() before the synth was ready
      this.active = null; // the song being played
      this.loading = null; // the song being evaluated
      this.playing = false;
      this.cycle = 0; // scheduled through this cycle
      this.scheduledUntil = 0; // synth seconds
      this.cps = config.default_cps;
      this.epoch = 0; // bumped by rewind(): replies from before it are dropped
      this.results = [];
      this.output = new Float32Array(0);
      synthModuleFor(wasmBase64)
        .then((module) => WebAssembly.instantiate(module))
        .then((instance) => {
          if (this.closed) return;
          const synth = instance.exports;
          synth.music_init(config.sample_rate);
          synth.music_set_master_gain(config.master_gain);
          this.synth = synth;
          this.fields = synth.music_event_fields();
          this.ready = true;
          if (this.waitingCode !== null) this.startLoad(this.waitingCode);
          this.waitingCode = null;
        })
        .catch((error) => {
          this.broken = clip('music synth failed to start: ' + error);
          if (this.waitingCode !== null) this.report(false, this.broken);
          this.waitingCode = null;
        });
    }

    // The outcome of a load (song_loaded), or with `loaded` false a note
    // about the playing song (a warning only, as on desktop).
    report(ok, message, loaded = true) {
      this.results.push({ ok, loaded, message: clip(message) });
    }

    dispose(song) {
      clearTimeout(song.timer);
      song.worker.onmessage = null;
      song.worker.onerror = null;
      song.worker.terminate();
      if (this.loading === song) this.loading = null;
      if (this.active === song) {
        this.active = null;
        this.playing = false;
      }
    }

    // A song still loading fails its load; the playing one is just stopped
    // (silence until the next song, like a desktop song whose queries fail).
    fail(song, message) {
      const loaded = song.stage !== 'play';
      this.dispose(song);
      this.report(false, loaded ? message : 'the playing song was stopped: ' + clip(message), loaded);
    }

    load(code) {
      if (this.closed) return;
      if (this.broken) this.report(false, this.broken);
      else if (!this.ready) this.waitingCode = code;
      else this.startLoad(code);
    }

    startLoad(code) {
      if (this.loading) this.dispose(this.loading); // a newer song supersedes one still loading
      // `queries`: unanswered queries, oldest first ({ epoch, begin, seconds }).
      const song = { worker: new Worker(this.workerUrl, { type: 'module' }), stage: 'boot', code, queries: [], framesWaiting: 0, timer: 0 };
      song.timer = setTimeout(() => this.fail(song, 'the music engine took too long to start'), this.config.boot_time_limit_msec);
      song.worker.onmessage = (event) => this.onMessage(song, event.data);
      song.worker.onerror = (event) => {
        event.preventDefault?.();
        this.fail(song, event.message || 'the song crashed');
      };
      this.loading = song;
    }

    onMessage(song, m) {
      if (!m || typeof m !== 'object') return this.fail(song, BAD_SONG);
      if (m.type === 'ready' && song.stage === 'boot') {
        clearTimeout(song.timer);
        if (m.fields !== this.fields) return this.fail(song, 'music host and synth disagree on the event layout');
        song.stage = 'load';
        song.timer = setTimeout(() => this.fail(song, 'the song took too long to load'), this.config.load_time_limit_msec);
        song.worker.postMessage({ type: 'load', code: song.code });
      } else if (m.type === 'loaded' && song.stage === 'load') {
        clearTimeout(song.timer);
        if (m.ok !== true) return this.fail(song, m.error);
        song.stage = 'play';
        const previous = this.active;
        if (previous) {
          // What the old song was still asked for is lost with it: the new
          // one is asked for that stretch again, so the change has no gap.
          const first = previous.queries.find((q) => q.epoch === this.epoch);
          if (first) {
            this.cycle = first.begin;
            this.scheduledUntil = first.seconds;
          }
          this.dispose(previous);
        }
        this.loading = null;
        this.active = song;
        const c = this.config;
        this.cps = Number.isFinite(m.cps) && m.cps > 0 ? Math.min(Math.max(m.cps, c.min_cps), c.max_cps) : c.default_cps;
        this.playing = true;
        const warnings = Array.isArray(m.warnings) ? m.warnings.slice(0, MAX_WARNINGS).map(clip) : [];
        this.report(true, warnings.join('\n'));
      } else if (m.type === 'events' && song.stage === 'play' && song.queries.length > 0) {
        song.queries.shift();
        song.framesWaiting = 0;
        if (m.epoch === this.epoch && song === this.active) this.schedule(m.records);
      } else {
        this.fail(song, BAD_SONG); // not the reply that was due
      }
    }

    schedule(records) {
      const { synth, fields } = this;
      if (!(records instanceof Float64Array) || records.length % fields !== 0) return;
      const capacity = synth.music_max_events();
      const total = Math.min(records.length / fields, capacity * MAX_BATCHES_PER_REPLY);
      for (let done = 0; done < total; done += capacity) {
        const count = Math.min(capacity, total - done);
        new Float64Array(synth.memory.buffer, synth.music_event_buffer(), count * fields)
          .set(records.subarray(done * fields, (done + count) * fields));
        synth.music_schedule(count);
      }
    }

    // One scheduling pass.
    pump() {
      const song = this.active;
      const c = this.config;
      if (!this.ready || !song || !this.playing) return;
      if (song.queries.length > 0 && ++song.framesWaiting > c.reply_timeout_frames) {
        return this.fail(song, BAD_SONG);
      }
      const now = this.synth.music_time();
      // After a stall (or the first song), don't burst through the missed time.
      this.scheduledUntil = Math.max(this.scheduledUntil, now);
      let steps = Math.max(c.query_steps_per_cycle, 1);
      while (1 / (steps * this.cps) > c.lookahead * 0.5 && steps < c.max_steps_per_cycle) steps *= 2;
      const slice = 1 / steps;
      const target = now + c.lookahead;
      while (this.scheduledUntil < target && song.queries.length < c.max_steps_per_pump) {
        song.worker.postMessage({
          type: 'query', epoch: this.epoch, begin: this.cycle, end: this.cycle + slice,
          seconds: this.scheduledUntil, cps: this.cps,
        });
        song.queries.push({ epoch: this.epoch, begin: this.cycle, seconds: this.scheduledUntil });
        this.cycle += slice;
        this.scheduledUntil += slice / this.cps;
      }
    }

    // Silence, and the next song starts from cycle 0.
    rewind() {
      this.epoch++;
      this.cycle = 0;
      this.scheduledUntil = 0;
      this.playing = false;
      if (this.synth) this.synth.music_reset();
    }

    // rewind(), and a song still loading or waiting is dropped.
    halt() {
      this.rewind();
      this.waitingCode = null;
      if (this.loading) this.dispose(this.loading);
    }

    close() {
      this.halt();
      if (this.active) this.dispose(this.active);
      this.closed = true;
      this.synth = null;
      this.ready = false;
    }

    // Interleaved stereo float32 frames; zeros until the synth is ready.
    render(frames) {
      frames = Math.max(0, Math.floor(Number(frames) || 0));
      if (this.output.length !== frames * 2) this.output = new Float32Array(frames * 2);
      if (!this.ready) return this.output.fill(0);
      const synth = this.synth;
      const chunk = synth.music_max_frames();
      for (let done = 0; done < frames; done += chunk) {
        const count = Math.min(chunk, frames - done);
        this.output.set(new Float32Array(synth.memory.buffer, synth.music_render(count), count * 2), done * 2);
      }
      return this.output;
    }

    // Schedules, then the state as JSON: { time, voices, results: [{ ok, loaded, message }] }.
    tick() {
      this.pump();
      const state = JSON.stringify({
        time: this.ready ? this.synth.music_time() : 0,
        voices: this.ready ? this.synth.music_active_voices() : 0,
        results: this.results,
      });
      this.results = [];
      return state;
    }
  }

  const engines = new Map();
  let nextId = 1;
  const engine = (id) => engines.get(id) ?? null;

  globalThis.GHMusic = {
    // bundleText: strudel_bundle.mjs; wasmBase64: synth.wasm; configJson: see
    // web_music_engine.gd. Returns the engine's id.
    create(bundleText, wasmBase64, configJson) {
      const id = nextId++;
      engines.set(id, new Engine(String(bundleText), String(wasmBase64), JSON.parse(configJson)));
      return id;
    },
    load(id, code) { engine(id)?.load(String(code)); },
    restart(id) { engine(id)?.rewind(); },
    halt(id) { engine(id)?.halt(); },
    destroy(id) {
      engine(id)?.close();
      engines.delete(id);
    },
    tick(id) { return engine(id)?.tick() ?? ''; },
    render(id, frames) { return engine(id)?.render(frames) ?? new Float32Array(0); },
  };
})();
