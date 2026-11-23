# Gameplay roadmap: conclusions from the second reference pass

Written 2026-11-15 from [bt3_sauce.md](bt3_sauce.md) and
[god_hand_sauce.md](god_hand_sauce.md), after the report "the game is okay
but gets boring quick": hits and movement lack weight, the CPU is not a fun
opponent, too little variety, the same plan always wins. All four were
named, across every mode.

**Revised the same day after phase 0.** The first version of this file
proposed rebuilding the fighter around "soft hitstun" (a BT3 stagger the
victim can guard out of). You approved it. Then I played scripted fights in
the BT3 port and the claim turned out to be false. This version replaces
that plan.

Status: proposal, nothing implemented. I still have not played our game;
its numbers are read from code and tuning files.

## Phase 0 result: the hitstun claim was wrong

Measured in the BT3 PC port with `tools/reference/bt3_script.py` (scripted
pads, no window; details in bt3_sauce.md "Measured in the port"):

- A jab's real stun is about **20–30 frames**, the same order as ours
  (20). The 48-frame stagger animation has an early exit.
- A chained string lands in full against a held guard; a restarted string
  is blocked. That is how our strings already work.
- Confirmed as extracted: 40000 health, string damage 300 / 300 / 300 /
  410 / 580, hits 10–16 frames apart.

Consequences:

- BT3 and our game do **not** differ in how light hits work. The first
  version's central argument for a rebuild ("the gap is structural") rested
  on that difference and falls with it.
- Reading matching code was not enough to know how the game plays. Every
  other BT3 rule we plan to copy gets a scripted test first (the tool makes
  that a 25-second run).
- The differences that survive are real but mostly **quantitative or
  additive**: they can be tried on the current fighter before deciding
  whether it needs replacing.

## Answer (revised): step back, but do not rebuild yet

- **Step back: yes.** Stop adding features; align what exists with the
  references' measured numbers and rules, and playtest each step.
- **Rebuild the fighter: not decided.** Stage 1 below runs on the current
  core. The rebuild question comes back at stage 2 with a concrete trigger:
  if adding the reaction table and follow-ups to `fighter.gd` (2791 lines)
  is fighting the code, we split it into actions and records then.
- **Keep** the director, input, rollback, online, co-op run logic, tests
  and tools in every case.

## What still separates us from the references

| Complaint | What the references do | What we do | Evidence |
|---|---|---|---|
| Hits and movement lack weight | BT3: no hitstop; jab shake 3 for 0.1 s and a 100-unit push, smash shake 5–7 for 0.3 s and a 1000–2000 blow-away with floor and wall crashes; the attacker lunges into each hit and stops on contact. Jabs start on frame 8–12; enders and smashes are stuck ~100 frames unless they land. A jab is 0.75% of health. God Hand: close camera, victim slow-motion, seven launch strengths, floaty fall. | Hitstop 4 vs 8, one knockback vector, one gravity. Jab 5f startup, 20 total, default recovery 12. A jab is 3% of health. | damage and string timing measured; shake, push, recoveries from data |
| Same plan always wins | BT3: guard is free against jabs but a charged smash is unblockable in the wrong pose or costs a full ki bar; the Z-counter only works on smashes and finishers; trades go to the higher priority; two strings meeting guard each other; smashes charge up to 4× faster as you land hits. God Hand: enemies start guarding after 1–4 hits (your answer), and only a slow guard break opens them. | Ki guard costs 4–5% of a bar, the Z-counter works on jabs, trades hit both, nothing changes during a fight. | data and code, **not yet played** |
| CPU is not a fun opponent | Authored per type: BT3 rule tables over a situation word, 32 personality profiles, weighted combo branches; God Hand hand-written dice per enemy type with circling / watching / hopping away, long telegraphs and recoveries, a level meter. | One parametric brain; difficulty = shorter reaction delay. | code |
| Too little variety | Situational: reaction of the victim, momentum, walls and floor, back hits; God Hand adds player-built strings. BT3's 161 characters share one moveset. | Few situations; roster by profiles (same method as BT3, fine). | data |

## Plan (revised)

Every item is tested in the reference first when a script can do it, then
implemented, then **played by you**. Sim rules as always: determinism lint,
rollback test, save/load round trip.

**Stage 0. Finish ground truth.**
- BT3 by script: a charged smash into each guard pose (plain / ki guard /
  unblockable / push-off and the ki actually paid); a jab against a smash
  (priority); Z-counter attempts against a jab and against a smash; smash
  charge time before and after a long string (momentum); what a blow-away
  into the floor and the ring edge does.
- A frame-data sheet tool for our moves (startup, active, recovery,
  advantage on hit and on guard, damage %, push), to compare on paper.
- God Hand: the third pass (2026-11-23, God Hand: Rearmed + the retail
  ELF) answered the dodges and the crowd rules from code
  ([god_hand_reference.md](god_hand_reference.md)). Still open: hitstop
  length (two runtime words) and per-move cancel windows (motion data);
  Rearmed's test mode could measure both like `bt3_script.py` does.

**Stage 1. Numbers pass on the current fighter** (one branch, one playtest).
- Damage scale: about 0.75% per jab, ~5% per full string; round timer and
  best-of retuned. *(Longer rounds: approved.)*
- Frame data from BT3's tables through `tools/generate_moves.gd`: jab
  startup ~8, enders and smashes long with on-hit cancels only.
- Impact: no hitstop on lights; per-move camera shake, approach speed and
  push with BT3's ratios; much larger travel on smashes.
- Whichever of these stage 0 confirms: priority trades, mid-string
  auto-guard, Z-counter on smashes and finishers instead of jabs, ki guard
  at a real price.
- **Gate:** does it feel better? Which complaint is still there?

**Stage 2. Reactions and states.** Reaction table (heavy stagger, bounce,
blow-away with crashes, stun), follow-ups by the victim's reaction,
momentum, then God Hand's converters: guard break, floaty juggles, dizzy →
pummel (a decaying stun gauge: 200, 5 s dizzy), downed → stomp, victim
slow-motion. God Hand's dodge split goes here too: short invulnerable
starts (sway 10f, back-flip 24f), a duck that only removes the upper
hurtbox and loses to **low** attacks, a near-miss reward and a duck
counter in place of the perfect-dodge freeze. *Decide here whether the
fighter is rebuilt as actions + attack records + reaction table (shape in
the appendix).*

**Stage 3. Opponents.** CPU as situation word → weighted rules →
personalities, tells and level-scaled recoveries, a level meter; co-op
enemies as a few authored types, placed by God Hand's crowd rules
(distance rank → approach ring, flankers walk to the front, back-hold
cones by level, no attacks on a grabbed player; reference "Enemies as a
group").

**Stage 4. Variety.** String loadouts *(approved)*, skill flags per
character.

## Your decisions so far

| Question | Your answer | Now |
|---|---|---|
| Soft hitstun | approved | **withdrawn by me**: BT3 does not work that way (phase 0) |
| Longer rounds | approved | stands (stage 1) |
| String loadouts | yes | stands (stage 4) |
| Co-op and online stay on the old core until a switch-over | yes | moot for now: stage 1 changes the shared core, so every mode gets it; `matchup_sim` and `coop_sim` rerun after |
| I may drive the games | yes | done for BT3 (headless); not yet for God Hand |
| God Hand enemies guard after how many hits | random, 1 to 4 | recorded in god_hand_sauce.md |
| (2026-11-23) Y mid-string | BT3 finisher by string position; fwd + Y = upper hook, back + Y = sweep | done |
| Neutral Y in close range | melee heavy (body blow, stagger) + fwd / back variants; ki blast out of range | done |
| Holding Y | BT3 charged finisher / charged heavy / charged ki blast | done |
| When the victim falls | BT3 reactions: launchers, sweeps, smashes ≥30%, full-string finisher, throws | done |
| X string length | 5 (BT3 ender) | done |
| Frame data | structure first, BT3 frame-data pass later (stage 1) | stands |
| Juggle | God Hand floaty fall + ground juggle hits | done |
| After a tapped Y finisher | string ends; follow-ups only on hit | done |

Earlier decisions stage 1 would reverse if stage 0 confirms them: guard
vanish on string openers (→ on smashes and finishers), hitstop 4 / 8 on
normals (→ none on lights), jab timing and damage, ki guard price, +3 ki
per hit taken, both-hit trades. The 2-bar vanish escape from hitstun is
**no longer proposed for removal**: with real hitstun it keeps its job.

## Not done

- **God Hand played.** Still nothing was run. Since 2026-11-23 the
  God Hand: Rearmed port is installed (`~/Downloads/God Hand Rearmed/`):
  its test mode plays a recorded pad from a save state and writes a CSV
  row per game frame (Gene's and the enemies' state, HP, motion frame,
  hitstop). It is a Windows exe (Wine + your ISO), not tried yet. Open
  questions there: hitstop length, whether counter hits stagger harder,
  per-move cancel frames. Which dodge beats which attack is now answered
  in code.
- BT3 rules listed in stage 0.
- Our game was not run.

## Appendix: shape of a rebuilt fighter core (only if stage 2 calls for it)

Borrowed from how BT3 is organised (structure, not code), under our rules
(`sim_tick` only, `DetMath`, everything in `save_state`):

- **Actions** with enter / run / decide / leave, each naming which input
  groups are live, instead of one state machine.
- **Attack records** (the next `MoveData`): damage, guard damage, ki gain,
  momentum gain, approach speed, push on hit and guard, launch angles,
  shake on hit and guard, priority, guard result per pose, the reaction it
  causes per victim state, flags (Z-counterable, turns the victim, ignores
  armour).
- **A reaction table**: reaction id → action, with its rules in one place
  (mash speeds it up, counts toward anti-loop, stun length, crashes).
- **Follow-up tables** keyed by the victim's reaction.
- Frame data stays numbers in the record (we have no skeletal animation).
- A per-fighter time scale in the sim for victim slow-motion.
- The `Fighter` public contract is kept so CPU, HUD, VFX and camera keep
  working. Cross-cutting, so it would need `docs/SPEC_COMBAT.md` first.
