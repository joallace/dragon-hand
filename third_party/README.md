# Third-party sources

Unmodified copies, loaded at run time by the music engine (through
`JsRuntime` on desktop, the browser's own JS engine on web). Do not edit
them: update by copying the same files again from a newer commit.

| Directory | Source | Version | License |
|---|---|---|---|
| `strudel/core/` | https://codeberg.org/uzu/strudel `packages/core/*.mjs` | commit `cac73dc558a689ef877354ab6ce53edc2c06f80b` (2026-11-15) | AGPL-3.0-or-later (`strudel/LICENSE`) |
| `strudel/mini/` | same repo, `packages/mini/{index.mjs,mini.mjs,krill-parser.js}` | same commit | AGPL-3.0-or-later |
| `fraction.js/` | https://github.com/rawify/Fraction.js `dist/fraction.mjs` | tag `v5.2.1` | MIT (`fraction.js/LICENSE`) |

Strudel being AGPL-3.0 means a game that ships it is distributed under
AGPL-3.0 as well.
