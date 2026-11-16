// What Strudel's packages expect from a host, for runtimes that lack it
// (JsRuntime has no console, timers or performance; a browser has them all).
// Imported first by host.mjs. The console stays silent: song errors reach
// the game as exceptions from music_load().
const quiet = () => {};
globalThis.console ??= { log: quiet, info: quiet, debug: quiet, warn: quiet, error: quiet };
globalThis.performance ??= { now: () => Date.now() };
// Strudel's own scheduler is never started (the game schedules), so timers
// only need to exist.
globalThis.setInterval ??= () => 0;
globalThis.clearInterval ??= quiet;
globalThis.setTimeout ??= () => 0;
globalThis.clearTimeout ??= quiet;
