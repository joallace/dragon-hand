// Web music backend, evaluated in the page by WebMusicEngine (see
// web_music_engine.gd). Defines window.GHMusic, a table of engines: create()
// returns an id that every other call takes, so engines never share state.
//
// - Synth: native/strudel/src/synth.c as WebAssembly (synth.wasm), one
//   instance per engine inside an AudioWorkletProcessor, so it renders on the
//   browser's audio thread into our own AudioContext. It does not go through
//   Godot's mixer: in the single-threaded web build that one is fed from the
//   main thread, and breaks up whenever frames are slower than its buffer
//   (mobile Chrome). Events reach the processor by message, `lookahead`
//   ahead; it reports its clock and output level back.
// - Songs: each one gets its own module Worker that imports the Strudel
//   bundle, so songs are isolated from the page and from each other, and one
//   that hangs or misbehaves is terminated. A new song replaces the playing
//   one only once it has loaded.
// - A spare worker is booted while a song plays (importing the bundle is the
//   slow part of a song change), so the next song only has to be evaluated.
// - Scheduling mirrors StrudelEngine._schedule_ahead (strudel_engine.gd):
//   slices of a cycle are queried `lookahead` seconds ahead of the synth
//   clock; here the queries are messages, answered between frames. tick()
//   (once per game frame) schedules and reports whether or not audio is
//   running, so a song's result arrives even while the page's audio is
//   suspended (browsers start it only after the first click or key press).
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
  const PROCESSOR_NAME = 'gh-music';
  const REPORT_SECONDS = 0.02; // how often a processor reports its state
  const GAIN_SMOOTHING_SECONDS = 0.03;
  const MAX_GAIN = 4;
  const SPARE_ATTEMPTS = 2; // failed spare workers before giving up on them
  // Gestures that let a browser start audio.
  const UNLOCK_EVENTS = ['pointerdown', 'pointerup', 'touchend', 'keydown', 'click'];
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

  // The synth, on the audio thread. Messages in: events { epoch, records },
  // reset { epoch }, close. Out: state { epoch, time, voices, peak, sum,
  // frames } (the level of what was rendered since the last one). Events
  // from before the last reset are dropped.
  const PROCESSOR_SOURCE = `
    class GHMusicProcessor extends AudioWorkletProcessor {
      constructor(options) {
        super();
        const o = options.processorOptions;
        const synth = new WebAssembly.Instance(new WebAssembly.Module(o.wasm), {}).exports;
        synth.music_init(sampleRate);
        synth.music_set_master_gain(o.master_gain);
        this.synth = synth;
        this.fields = synth.music_event_fields();
        this.capacity = synth.music_max_events();
        this.maxFrames = synth.music_max_frames();
        this.reportFrames = Math.max(1, Math.floor(sampleRate * o.report_seconds));
        this.view = new Float32Array(0);
        this.epoch = 0;
        this.open = true;
        this.peak = 0;
        this.sum = 0;
        this.frames = 0;
        this.port.onmessage = (event) => this.onMessage(event.data);
      }

      onMessage(m) {
        const synth = this.synth;
        if (m.type === 'events' && m.epoch === this.epoch) {
          const fields = this.fields;
          const total = Math.floor(m.records.length / fields);
          for (let done = 0; done < total; done += this.capacity) {
            const count = Math.min(this.capacity, total - done);
            new Float64Array(synth.memory.buffer, synth.music_event_buffer(), count * fields)
              .set(m.records.subarray(done * fields, (done + count) * fields));
            synth.music_schedule(count);
          }
        } else if (m.type === 'reset') {
          this.epoch = m.epoch;
          synth.music_reset();
        } else if (m.type === 'close') {
          this.open = false;
        }
      }

      process(inputs, outputs) {
        if (!this.open) return false;
        const left = outputs[0][0];
        if (!left) return true;
        const right = outputs[0][1] || left;
        const synth = this.synth;
        const frames = Math.min(left.length, this.maxFrames);
        const at = synth.music_render(frames);
        let view = this.view;
        if (view.length !== frames * 2 || view.buffer !== synth.memory.buffer) {
          view = this.view = new Float32Array(synth.memory.buffer, at, frames * 2);
        }
        let peak = this.peak;
        let sum = this.sum;
        for (let i = 0; i < frames; i++) {
          const l = view[i * 2];
          const r = view[i * 2 + 1];
          left[i] = l;
          right[i] = r;
          const a = Math.max(l < 0 ? -l : l, r < 0 ? -r : r);
          if (a > peak) peak = a;
          sum += l * l + r * r;
        }
        this.peak = peak;
        this.sum = sum;
        this.frames += frames;
        if (this.frames >= this.reportFrames) {
          this.port.postMessage({
            type: 'state', epoch: this.epoch, time: synth.music_time(), voices: synth.music_active_voices(),
            peak: this.peak, sum: this.sum, frames: this.frames,
          });
          this.peak = 0;
          this.sum = 0;
          this.frames = 0;
        }
        return true;
      }
    }
    registerProcessor(${JSON.stringify(PROCESSOR_NAME)}, GHMusicProcessor);
  `;

  // Shared by every engine: the worker script (by bundle text), the synth
  // (by its base64 text) and the audio output.
  let workerUrl = '';
  let workerBundle = null;
  let bundleUrl = '';
  let synthInfo = null;
  let synthBase64 = null;
  let audio = null; // { ctx, module }

  const blobUrl = (text) => URL.createObjectURL(new Blob([text], { type: 'text/javascript' }));

  function workerUrlFor(bundleText) {
    if (bundleText !== workerBundle) {
      // Running workers keep what they already imported.
      if (workerUrl) URL.revokeObjectURL(workerUrl);
      if (bundleUrl) URL.revokeObjectURL(bundleUrl);
      bundleUrl = blobUrl(bundleText);
      workerUrl = blobUrl(workerSource(bundleUrl));
      workerBundle = bundleText;
    }
    return workerUrl;
  }

  // Resolves to { bytes, fields, capacity }: the module's bytes (each
  // processor compiles its own copy; it is a few KB) and the event layout,
  // read from an instance on this thread.
  function synthInfoFor(wasmBase64) {
    if (wasmBase64 !== synthBase64) {
      synthBase64 = wasmBase64;
      synthInfo = Promise.resolve()
        .then(() => {
          const bytes = Uint8Array.from(atob(wasmBase64), (c) => c.charCodeAt(0));
          return WebAssembly.instantiate(bytes).then(({ instance }) => ({
            bytes,
            fields: instance.exports.music_event_fields(),
            capacity: instance.exports.music_max_events(),
          }));
        })
        .catch((error) => {
          // Not cached: the next engine tries again.
          if (synthBase64 === wasmBase64) synthBase64 = null;
          throw error;
        });
    }
    return synthInfo;
  }

  // The page's music output: one AudioContext for every engine. Latency
  // doesn't matter for music, so the browser may pick large, safe buffers.
  // It starts on the first gesture and sleeps while the page is hidden.
  function audioOutput() {
    if (audio) return audio;
    const Context = globalThis.AudioContext ?? globalThis.webkitAudioContext;
    if (!Context || !globalThis.AudioWorkletNode) throw new Error('no Web Audio worklets');
    const ctx = new Context({ latencyHint: 'playback' });
    const url = blobUrl(PROCESSOR_SOURCE);
    const wake = () => {
      if (ctx.state !== 'running' && !document.hidden) ctx.resume().catch(() => {});
    };
    const onVisibility = () => {
      if (document.hidden) ctx.suspend().catch(() => {});
      else wake();
    };
    const output = { ctx, module: null };
    output.module = Promise.resolve()
      .then(() => ctx.audioWorklet.addModule(url))
      .finally(() => URL.revokeObjectURL(url))
      .catch((error) => {
        // Not kept: the next engine tries again with a new context.
        if (audio === output) audio = null;
        for (const type of UNLOCK_EVENTS) removeEventListener(type, wake, { capture: true });
        document.removeEventListener('visibilitychange', onVisibility);
        ctx.close().catch(() => {});
        throw error;
      });
    for (const type of UNLOCK_EVENTS) addEventListener(type, wake, { capture: true, passive: true });
    document.addEventListener('visibilitychange', onVisibility);
    wake();
    audio = output;
    return audio;
  }

  class Engine {
    constructor(bundleText, wasmBase64, config) {
      this.config = config;
      this.workerUrl = workerUrlFor(bundleText);
      this.ctx = null; // the shared AudioContext
      this.node = null; // AudioWorkletNode running the synth
      this.gain = null; // GainNode: the game's music volume
      this.gainValue = 1;
      this.fields = 0;
      this.capacity = 0;
      this.ready = false;
      this.broken = ''; // why the synth could not start
      this.closed = false;
      this.waitingCode = null; // load() before the synth was ready
      this.active = null; // the song being played
      this.loading = null; // the song being evaluated
      this.spare = null; // a worker booted for the next song
      this.spareFailures = 0;
      this.settledAt = 0; // when the last song loaded (or a spare failed)
      this.playing = false;
      this.cycle = 0; // scheduled through this cycle
      this.scheduledUntil = 0; // synth seconds
      this.cps = config.default_cps;
      this.epoch = 0; // bumped by rewind(): what is from before it is dropped
      this.time = 0; // the synth clock, as last reported
      this.voices = 0;
      this.level = { peak: 0, sum: 0, frames: 0 }; // output since the last tick()
      this.results = [];
      Promise.resolve()
        .then(() => {
          const output = audioOutput();
          return Promise.all([synthInfoFor(wasmBase64), output.module.then(() => output.ctx)]);
        })
        .then(([info, ctx]) => {
          if (this.closed) return;
          this.ctx = ctx;
          this.fields = info.fields;
          this.capacity = info.capacity;
          this.node = new AudioWorkletNode(ctx, PROCESSOR_NAME, {
            numberOfInputs: 0,
            numberOfOutputs: 1,
            outputChannelCount: [2],
            processorOptions: { wasm: info.bytes.slice().buffer, master_gain: config.master_gain, report_seconds: REPORT_SECONDS },
          });
          this.node.port.onmessage = (event) => this.onState(event.data);
          this.node.onprocessorerror = () => this.breakDown('music synth crashed');
          this.gain = ctx.createGain();
          this.gain.gain.value = this.gainValue;
          this.node.connect(this.gain).connect(ctx.destination);
          this.node.port.postMessage({ type: 'reset', epoch: this.epoch });
          this.ready = true;
          if (this.waitingCode !== null) this.startLoad(this.waitingCode);
          this.waitingCode = null;
        })
        .catch((error) => this.breakDown('music synth failed to start: ' + error));
    }

    // No sound from here on: every load fails with `reason`.
    breakDown(reason) {
      if (this.closed || this.broken) return;
      this.broken = clip(reason);
      this.ready = false;
      this.playing = false;
      if (this.waitingCode !== null || this.loading) this.report(false, this.broken);
      this.waitingCode = null;
      for (const song of [this.loading, this.active, this.spare]) if (song) this.dispose(song);
      this.disconnect();
    }

    disconnect() {
      if (this.node) {
        this.node.port.postMessage({ type: 'close' });
        this.node.port.onmessage = null;
        this.node.onprocessorerror = null;
        this.node.disconnect();
      }
      this.gain?.disconnect();
      this.node = null;
      this.gain = null;
    }

    // A processor's report.
    onState(m) {
      if (!m || m.type !== 'state' || m.epoch !== this.epoch) return;
      this.time = Number(m.time) || 0;
      this.voices = Number(m.voices) || 0;
      this.level.peak = Math.max(this.level.peak, Number(m.peak));
      this.level.sum += Number(m.sum);
      this.level.frames += Number(m.frames) || 0;
    }

    setGain(value) {
      value = Math.min(Math.max(Number(value) || 0, 0), MAX_GAIN);
      if (value === this.gainValue) return;
      this.gainValue = value;
      if (this.gain) this.gain.gain.setTargetAtTime(value, this.ctx.currentTime, GAIN_SMOOTHING_SECONDS);
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
      if (this.spare === song) this.spare = null;
      if (this.active === song) {
        this.active = null;
        this.playing = false;
      }
    }

    // A song still loading fails its load; the playing one is just stopped
    // (silence until the next song, like a desktop song whose queries fail).
    fail(song, message) {
      if (song === this.spare) {
        // Nothing was asked of it yet: the next song boots its own worker.
        this.spareFailures++;
        this.settledAt = performance.now();
        return this.dispose(song);
      }
      if (song.adopted && song.stage === 'boot') {
        // A spare that was given a song before it had booted, and didn't
        // make it: the song gets a worker of its own.
        this.dispose(song);
        this.loading = this.boot(song.code);
        return;
      }
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

    // A worker importing the bundle; `code` is null for a spare.
    boot(code) {
      // `queries`: unanswered queries, oldest first ({ epoch, begin, seconds }).
      const song = { worker: new Worker(this.workerUrl, { type: 'module' }), stage: 'boot', code, queries: [], framesWaiting: 0, timer: 0 };
      song.timer = setTimeout(() => this.fail(song, 'the music engine took too long to start'), this.config.boot_time_limit_msec);
      song.worker.onmessage = (event) => this.onMessage(song, event.data);
      song.worker.onerror = (event) => {
        event.preventDefault?.();
        this.fail(song, event.message || 'the song crashed');
      };
      return song;
    }

    startLoad(code) {
      if (this.loading) this.dispose(this.loading); // a newer song supersedes one still loading
      const song = this.spare;
      if (!song) {
        this.loading = this.boot(code);
        return;
      }
      this.spare = null;
      this.loading = song;
      song.code = code;
      song.adopted = true;
      if (song.stage === 'idle') this.sendLoad(song); // else once it is ready
    }

    sendLoad(song) {
      clearTimeout(song.timer);
      song.stage = 'load';
      song.timer = setTimeout(() => this.fail(song, 'the song took too long to load'), this.config.load_time_limit_msec);
      song.worker.postMessage({ type: 'load', code: song.code });
    }

    // Boots the next song's worker once the playing one has settled, so that
    // importing the bundle doesn't compete with a song (or a scene) loading.
    keepSpare() {
      if (this.spare || this.loading || !this.active || this.spareFailures >= SPARE_ATTEMPTS) return;
      if (performance.now() - this.settledAt < this.config.spare_delay_msec) return;
      this.spare = this.boot(null);
    }

    onMessage(song, m) {
      if (!m || typeof m !== 'object') return this.fail(song, BAD_SONG);
      if (m.type === 'ready' && song.stage === 'boot') {
        clearTimeout(song.timer);
        if (m.fields !== this.fields) return this.fail(song, 'music host and synth disagree on the event layout');
        if (song.code === null) song.stage = 'idle'; // a spare: waits for its song
        else this.sendLoad(song);
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
        this.settledAt = performance.now();
        const warnings = Array.isArray(m.warnings) ? m.warnings.slice(0, MAX_WARNINGS).map(clip) : [];
        this.report(true, warnings.join('\n'));
      } else if (m.type === 'events' && song.stage === 'play' && song.queries.length > 0) {
        // The epoch is the one the query was sent with, not what the worker says.
        const asked = song.queries.shift();
        song.framesWaiting = 0;
        if (asked.epoch === this.epoch && song === this.active) this.schedule(m.records);
      } else {
        this.fail(song, BAD_SONG); // not the reply that was due
      }
    }

    schedule(records) {
      const { fields } = this;
      if (!this.node || !(records instanceof Float64Array) || records.length % fields !== 0) return;
      const total = Math.min(records.length / fields, this.capacity * MAX_BATCHES_PER_REPLY);
      if (total === 0) return;
      if (total * fields < records.length) records = records.slice(0, total * fields);
      this.node.port.postMessage({ type: 'events', epoch: this.epoch, records }, [records.buffer]);
    }

    // One scheduling pass.
    pump() {
      const song = this.active;
      const c = this.config;
      if (!this.ready || !song || !this.playing) return;
      if (song.queries.length > 0 && ++song.framesWaiting > c.reply_timeout_frames) {
        return this.fail(song, BAD_SONG);
      }
      const now = this.time;
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

    // Silence, and the next song starts from cycle 0. The synth clock reads
    // 0 until the processor has reset (its older reports are ignored).
    rewind() {
      this.epoch++;
      this.cycle = 0;
      this.scheduledUntil = 0;
      this.playing = false;
      this.time = 0;
      this.voices = 0;
      if (this.node) this.node.port.postMessage({ type: 'reset', epoch: this.epoch });
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
      if (this.spare) this.dispose(this.spare);
      this.closed = true;
      this.ready = false;
      this.disconnect();
    }

    // Schedules, then the state as JSON: { time, voices, running, peak, sum,
    // frames, results: [{ ok, loaded, message }] }. `running`: the audio
    // output is. peak / sum (of squares, both channels; -1 if not a number)
    // / frames describe the synth's output since the last tick.
    tick() {
      this.pump();
      this.keepSpare();
      const level = this.level;
      const state = JSON.stringify({
        time: this.time,
        voices: this.voices,
        running: this.ctx !== null && this.ctx.state === 'running',
        peak: Number.isFinite(level.peak) ? level.peak : -1,
        sum: Number.isFinite(level.sum) ? level.sum : -1,
        frames: level.frames,
        results: this.results,
      });
      this.level = { peak: 0, sum: 0, frames: 0 };
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
    // The game's music volume (linear), applied after the synth.
    gain(id, value) { engine(id)?.setGain(value); },
  };
})();
