# Gameplay roadmap: conclusions from the second reference pass

Written 2026-11-15 from [bt3_sauce.md](bt3_sauce.md) and
[god_hand_sauce.md](god_hand_sauce.md), after the report "the game is okay
but gets boring quick": hits and movement lack weight, the CPU is not a fun
opponent, too little variety, the same plan always wins. All four were
named, across every mode.

Status: **proposal, nothing implemented.** The numbers about our game are
read from the code and tuning files; I did not play it, and I did not play
the two references either (open checks are listed at the end).

## Answer: step back, rebuild the fighter, keep the platform

Yes, we should step back. But the thing to redo is narrower than "the
game" and deeper than "the tuning":

- **Keep:** the deterministic 60 Hz director, `InputFrame` / input sources,
  save/load and rollback, sessions and lobby, co-op run logic, the event
  hub, settings, the test harness and tools. None of the findings touch
  them, and they are the expensive part.
- **Rebuild:** `gameplay/fighter/fighter.gd` (2791 lines), the combat
  resolution around it, `MoveData`'s shape, and afterwards `CpuBrain`
  (1736 lines). Build the replacement against a written combat spec, in a
  small playable slice, and switch over only when the slice feels better.

Why not keep tuning what exists:

1. **The gap is structural.** The first pass copied about twenty mechanics
   from the references (the ✅ tables in the reference files) and the game
   still does not feel like either. The second pass shows why: both games
   rest on a base we do not have (below), and you cannot reach it by
   editing `.tres` values. Hitstun that the defender can guard out of,
   reactions as a table with per-reaction rules, attacks resolved by
   priority, follow-ups chosen by the victim's reaction: each one changes
   what a "state" and a "move" are.
2. **The fighter grew by accretion.** Around fifteen feature branches each
   added states and exceptions to one script, and nearly every number in it
   is recorded as "my pick, not playtested". The references' numbers form a
   system (a jab's stagger, the smash charge time, the guard price and the
   recovery lengths only make sense together); ours were chosen one feature
   at a time.
3. **We now have the real tables.** BT3's per-move data is readable
   (`tools/reference/bt3_data.py`). A rebuild can start from a converted
   copy of a tuned game instead of from guesses.

## Diagnosis: what both games have and we lack

| Complaint | What the references do | What we do |
|---|---|---|
| Same plan always wins | A landed hit opens a **second decision for both players**. BT3: 48f stagger the victim can guard out of, so the attacker must beat the guard (charged smash by pose, throw, get behind) and the defender must guess. God Hand: enemies start guarding mid-string, only a slow guard break opens them. | 20f true hitstun on a 5f jab. The first hit decides; the defender's only out costs 2 ki bars. Guarding is nearly free (a ki guard is 4–5% of a bar; BT3: a full bar), trades hit both, the Z-counter works on jabs (BT3: only on smashes). |
| Hits and movement lack weight | **Dynamic range.** BT3: no hitstop; jab shake 3 for 0.1 s and a 100-unit push, smash shake 5–7 for 0.3 s and a 1000–2000 blow-away with floor / wall crashes; the attacker lunges into each hit and stops on contact. God Hand: close camera, victim slow-motion, seven launch strengths, floaty fall. Both: slow starts and long recoveries, so every action is a commitment. | Hitstop 4 vs 8 frames, one knockback vector, one gravity, one reaction per move. Jab 20 frames total, default recovery 12. Nothing takes long enough to be a commitment or travels far enough to be an event. |
| CPU is not a fun opponent | Behaviour is **authored per type**: BT3 rule tables over a situation word with 32 personality profiles and weighted combo branches; God Hand hand-written dice cascades per enemy type, with circling / watching / hopping away as real states, long telegraphs, long level-scaled recoveries, and a level meter that tracks the player. | One parametric brain for every character and enemy, difficulty = the same mind with a shorter reaction delay. |
| Too little variety | Variety is **situational**, not content: BT3's 161 characters share one moveset and differ by scalars and skill flags; what changes is the victim's reaction, momentum (smashes charge up to 4× faster as you land hits), walls, floor, back hits. God Hand adds player-built strings. | Few situations: a hit is a hit, the tenth exchange equals the first, the arena edge does nothing to a combo. (Our roster-by-profiles method is the same as BT3's and is fine.) |

One sentence: **the references make the moment after a hit interesting;
ours makes it automatic.**

## Design pillars for the rebuild

1. **Soft light hits, hard heavy hits.** Light staggers are long and can be
   guarded out of; heavy stagger, launch, bounce, blow-away, stun and guard
   crash are real. (BT3 §1)
2. **A closed counter table.** String < guard < charged smash / throw /
   back hit < Z-counter / break / turn < string. Every option has a price
   in time, ki or position, and no option is free against everything.
   (BT3 §2)
3. **Commit, and get paid for being right.** Readable startups, long
   recoveries, generous cancels *on hit only*, follow-ups that depend on
   the victim's reaction. (BT3 §3, God Hand §2)
4. **The victim's state picks the best move.** Guarding → break it;
   launched → juggle or wall; dizzy → pummel; downed → stomp or
   reposition. (God Hand §3)
5. **Dodge is the aggressive defence, guard the safe one.** Dodges are
   free, hold position and lead into your hit; guard is safe against light
   hits, expensive against heavy ones, and loses to throws. (God Hand §1)
6. **The fight changes while it lasts.** Momentum, ki prices on defence,
   position against the ring edge. (BT3 §4, §7)
7. **Weight is contrast.** Per-move shake, approach, push and travel across
   a 10× range; freezes and slow-motion only for hits that earned them.
   (BT3 §6, God Hand §6)
8. **Opponents have personalities.** Authored options per type, tells,
   recoveries, and a level meter for solo and co-op. (BT3 §9, God Hand §7)

## Earlier decisions this would reverse

"Full rewrite allowed" was your answer; these are still worth a conscious
yes, because several were explicit requests.

| Decision today | Proposed |
|---|---|
| Vanish escape out of hitstun for 2 bars | Removed. Guarding out of light staggers replaces it; heavy reactions have mash / air recovery. |
| Guard vanish (Z-counter) on string openers only | On smashes, finishers and other committed hits only; jabs are guarded, dodged or out-prioritised. |
| Hitstop 4 light / 8 heavy | 0 on lights, shake instead; short freeze or victim slow-motion on smashes, counters, crashes. |
| Jab 5f startup, 20f total, 20f hitstun | BT3-scale: ~8f startup, 22 total, ~48f soft stagger; enders and smashes ~100f with on-hit cancels. |
| Jab = 3% of health | Around 1% per jab, ~5% per full string: longer rounds, more exchanges per round. Timer and round count to be retuned. |
| Ki guard 4–5% of a bar | Up to a full bar for a fully charged smash in the wrong pose. |
| +3 ki per hit taken | None by default (BT3). One comeback mechanic at most, to be chosen in the slice. |
| Both fighters get hit on a trade | Priority decides; ties cancel both. Mid-string fighters auto-guard light hits. |
| One CPU brain, eight levels | Rule tables + personalities; levels scale rates; optional level meter. |

Unchanged: no flight, right-stick dodges and their measured God Hand
timings, BT3 guard poses and throws, teleport placement with the stick,
teams / co-op model, beams, rollback rules.

## Shape of the new fighter core

Borrowed from how BT3 is organised (structure, not code), fitted to our
rules (`sim_tick` only, `DetMath`, every variable in `save_state`):

- **Actions** instead of one state machine: each action has enter / run /
  decide / leave, and its decide step names which input groups are live.
  "Can I guard out of this?" becomes one bit on the action, not a branch in
  a 2800-line script.
- **Attack records** (the next `MoveData`): damage, guard damage, ki gain,
  momentum gain, approach speed, push on hit and on guard, launch angles,
  shake power and time for hit and guard, priority, guard result per pose,
  the *reaction it causes per victim state*, and flags (Z-counterable,
  instant-guardable, turns the victim, ignores armour).
- **A reaction table**: reaction id → action, with the per-reaction rules
  in one place (guardable or not, mash speeds it up, counts toward
  anti-loop, stun length, crash on floor / ring edge).
- **Follow-up tables** keyed by the victim's reaction.
- **Frame data as data**: we have no skeletal animation, so hit windows and
  cancel points stay numbers in the record, as today.
- **Per-fighter time scale** in the sim for victim slow-motion (a fixed-
  point accumulator per fighter; deterministic, saved).
- The `Fighter` public contract (what `CpuBrain` and the presentation read)
  is kept or adapted, so HUD, VFX, SFX and camera keep working.

This is cross-cutting (sim + save_state shape + net hashes), so by our own
workflow rule it needs a spec first: `docs/SPEC_COMBAT.md`, reviewed by you
before code.

## Phases

Each phase ends with **you playing it**. That is the change of method: the
last twenty features were verified by headless tests only, and tests cannot
see feel. Every phase also keeps `determinism_lint_test`, `rollback_test`
and a save/load round trip green for the new core.

**0. Ground truth (short).**
- Close the open checks below in the BT3 PC port and PCSX2.
- A frame-data sheet tool for *our* moves (startup, active, recovery,
  advantage on hit and on guard, damage %, push), so both cores can be
  compared on paper.
- `SPEC_COMBAT.md`: the counter table, reaction list, record fields and
  starting numbers converted from BT3's tables.

**1. Combat lab: the vertical slice.** A training scene with the new core,
one character, no specials, selectable next to the current game.
- Movement with BT3's ratios (slow close-range walk, dash, approach lunge
  per attack that stops on contact).
- Five-step string with real timing, ender, soft stagger, guard out of it,
  heavy stagger, launch, blow-away, floor and ring-edge crash.
- Priority trades, mid-string auto-guard, anti-loop by reaction.
- Impact layer: per-move shake, no hitstop on lights, victim travel.
- Dummy modes: stand, guard always, guard after N hits, mash, record /
  replay.
- **Gate:** does hitting the dummy and being hit feel better than the
  current game? If not, we stop here and have lost a slice, not the game.

**2. The counter table.** Charged smashes by pose with ki-guard prices,
momentum, Z-counter against smashes, throws and breaks, getting behind,
dodges as the in-place defence with a punish window, counter hits.
**Gate:** two humans (or you against a recorded dummy) find more than one
working plan.

**3. States and converters.** Guard break moves, juggles with a floaty
fall, dizzy → pummel, downed → stomp, victim slow-motion. Then re-home
what the old core had: ki charge and prices, teleports, specials, beams,
taunt, get-up options, characters by scalar profile.

**4. Opponents.** CPU as situation word → weighted rules → personalities,
with tells and level-scaled recoveries; a level meter mode. Co-op enemies
as a few authored types, each with a short option list.

**5. Variety.** String loadouts (a move pool and per-player strings),
skill flags per character (who has which step, parry or finisher).

**6. Switch over.** Port co-op states (downed / revive / entering) and
online, rerun `net_bench`, `matchup_sim`, `coop_sim`, delete the old core.

Phases 1 and 2 are the bet. Everything after depends on their gates.

## Open checks before copying a number

Cheap to do by playing; no recording with input display needed.

BT3 (PC port in `~/Downloads/Tenkaichi3Decomp`):
- Hold guard after being hit by the first rush punch: on which hit does the
  guard come up? (Code says it can; the feel is unmeasured.)
- Does a fresh string started on a staggered opponent get blocked on its
  first hit while a continued one does not?
- Health pool of a standard character (I assumed 40000).
- How strong the momentum effect is on smash charge after a long string.

God Hand (PCSX2):
- After how many hits basic enemies start guarding, and what a guard break
  does to them.
- Hitstop on a jab versus a heavy; whether counter hits stagger harder.
- Which dodge beats which enemy attack.

Ours: I have not run the game. The diagnosis is from numbers; tell me where
it does not match what you feel.

## Decisions I need from you

1. **Soft hitstun.** It turns the game from "combo game" into "pressure
   game". It is the heart of the proposal; everything else follows from
   it.
2. **Longer rounds** (about three times as many hits per round), with the
   timer and best-of to match.
3. **String loadouts**: in the plan, or leave variety to characters.
4. **Co-op and online stay on the old core** until phase 6 (they keep
   working, but get nothing new meanwhile). Acceptable?
5. May I drive the BT3 port and PCSX2 on your screen for phase 0, or do you
   prefer to answer the checks yourself?
