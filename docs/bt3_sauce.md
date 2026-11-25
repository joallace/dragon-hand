# Budokai Tenkaichi 3: where the feel comes from

Second research pass (2026-11-15), after "our game is okay but gets boring
quick". [bt3_reference.md](bt3_reference.md) lists BT3's *rules*; this file
is about why those rules stay fun for hundreds of matches, and it adds what
the first pass could not read: **the per-move tuning data**.

What changed since October: the decomp
(https://github.com/z3xox/Tenkaichi3Decomp, read at its 2026-11-03 state)
now documents the attack record, the character parameter block and the
animation file, and the PC port installed on this machine has the disc
unpacked. `tools/reference/bt3_data.py` reads those tables from your own
copy (`atk`, `anim`, `param`, `roster`). Everything marked **[D]** below was
read that way; **[V]** is matching C; **[I]** is my inference from the two;
**[K]** is general knowledge of the game, not checked in code.

Mechanics and numbers only, in our own words. No decomp code, no data files
in the repo.

Frame counts are **60 Hz** (game frames ×2) unless marked `@30`. Speeds stay
in the game's own "km/h": only their ratios matter (the world scale is
unconfirmed, probably ~10 units per metre).

## The short version

BT3's light hits are **not** special: a jab stuns for about as long as ours
does, and a string is a true combo only while you keep chaining it. What
BT3 does differently is everything *around* that: slower starts, very long
recoveries that only success cancels, trades decided by priority, a guard
that is free against jabs and expensive against charged hits, a counter
that only works on committed hits, charge speed that grows as you land
hits, and a tenfold gap between how a light and a heavy hit move the
victim.

(The first version of this file claimed the opposite about hitstun, from
reading the code. Playing scripted fights in the port proved it wrong; see
"Measured in the port" below.)

## 1. What a landed jab is worth (measured)

Measured with `tools/reference/bt3_script.py`, Goku (Early) against Goku
(Early), frames at 60 Hz:

- **Effective light hitstun is about 20–30 frames**, not the 48 of the
  stagger animation. A victim who mashes rush after one jab lands their own
  jab 30 frames after being hit (so they were free 16–22 frames after the
  hit). A victim holding guard is still hit by a follow-up arriving 22
  frames after the first hit, and blocks one arriving at 32. The stagger
  animation has an early exit; its tail is only cosmetic.
- The attacker is free 14 frames after their jab connects, or can chain
  from 4. So a lone jab is somewhere between **+2 and +16**: the same order as
  ours (hitstun 20, about +5).
- **A chained string is a true combo against a held guard.** With guard
  held from 6 frames after the first hit, all five hits still land (300,
  300, 300, 410, 580 at intervals of 10, 16, 16 and 14 frames).
- **A restarted string is not.** Leave the chain and press again: the new
  first hit is blocked by a victim who is holding guard, and a victim who
  attacks instead gets their jab out first.

So the jab game is the ordinary one: confirm the first hit, finish the
string, and choose **inside the string** how to end it (the finisher on the
second button, a charged smash, a throw, a step). BT3's depth after a hit
is in those branch points and in the heavy reactions (heavy stagger and
ground bounce that only mashing shortens, stun of 30/60/90 frames, launches
and blow-aways with recovery from frame 18), not in the jab's stun.

The code also has an "instant guard" for a staggered fighter holding guard
against hits flagged for it (the first rush hit and uncharged smashes and
finishers, on all 161 characters [D]). In the measurements above the
victim is simply free by then, so I could not tell the two apart; treat it
as a detail, not a pillar.

## 2. Every answer has a counter-answer

Read from the attack records of all 161 characters [D] plus the hit code
[V]:

| Attacker does | It beats | It loses to |
|---|---|---|
| Rush string (priority 1, enders 5) | anyone pressing buttons, steps, charging | plain guard (free, no ki); an opponent mid-rush auto-guards it |
| Smash, uncharged (priority 20) | rush (wins trades) | any guard pose (plain), Z-counter |
| Up / down smash charged ≥30% | **unblockable** against one of the two directional guard poses | the other two poses (plain), Z-counter |
| Side / neutral smash charged ≥30% | the directional poses pay **1 ki bar** (ki guard) | mid guard (plain), Z-counter |
| Full-charge smash (priority 25) | up / down: unblockable in one pose, 1 bar in mid. Side: unblockable in both directional poses, 1 bar in mid | up / down: the opposite pose gets a **push-off** (attacker recoils, defender +0.5 blast stock). Z-counter |
| Dash smash (priority 30, 40 at full) [I] | everything in a trade | Z-counter, side step |
| Throw | all guards | guard press in a 10f window, anything that hits first |
| Getting behind (vanish, circle dash) | guard (fails from behind), +20% damage | 1 bar / 0.5 bar, lock-on turn |

Two details matter more than they look:

- **The Z-counter is an anti-smash tool, not an anti-jab tool.** The
  "first hit can be evaded" flag is clear on every rush punch of every
  character and set on every smash [D]. You cannot vanish through jabs;
  you guard them. You vanish through the slow, committed, guard-breaking
  hits. Ours does the reverse ("string openers only").
- **Ki guard is expensive.** The record's guard ki price is one full bar
  (20000 of 100000) on every attack [D], charged only when the guard result
  is "ki guard". Ours prices a ki guard at 4–5% of a bar, so guarding is
  never a real decision.
  *Measured (2026-11-25, "Measured in the port"): a smash into a ki-guard
  pose cost about half a bar (9440–11040; 18400 for a full down smash),
  growing with the charge; the Z-counter worked on a smash and never on a
  jab. Ours today ([frame_data.md](frame_data.md)): 15% of a bar for an
  uncharged smash, 25–35% for finishers, more as the charge grows, and a
  full charge crashes any guard (75 frames open), which BT3 never did in
  these runs.*

## 3. Commitment: long recoveries, cancelled only by success

Goku's frame data [D] (60 Hz; hit window = when the hit volumes are live):

| Move | Hit window | Next input | Total | Ours |
|---|---|---|---|---|
| Rush 1 | 8–18 | 12 | 22 | jab 5 startup, 20 total |
| Rush 2 | 4–16 | 10 | 22 | |
| Rush 3 | 10–20 | 12 | 24 | |
| Rush 4 | 16–24 | 20 | 26 | |
| Rush 5 (ender) | 18–30 | follow-ups from 40% **only if it hit** | **110** | |
| Charged smash release | 12–28 | ~16–26 | **~100–112** | |
| Smash wind-up before the charge loop | – | – | 16–32 | |

*Measured: wind-up ~16 frames, then 42 frames of charge to full (cold).
After a plain-guarded full smash the attacker was idle again ~42 frames
after the hit, shorter than the ~100 above suggests; not resolved (the
whiff case was not run).*

Across the roster the median jab is 26 frames long with its first hit on
**frame 12** (fastest 2, slowest 38) [D]. BT3's jabs are less than half as
fast as ours.

The pattern: an attack that is guarded or whiffed leaves you stuck for
most of a second; an attack that **lands** opens follow-up branches at 40%
(ender), 60–70% (smash), chosen by the victim's reaction (the follow-up
table is indexed by which reaction the opponent is in [V]). Hit confirms
are generous, mistakes are loud. That is what makes a read feel like a
read.

## 4. Momentum: the fight heats up

Each fighter carries a 0..100000 momentum gauge [V]. Every rush hit adds
8000 (first half of the string) or 14400 (second half); other moves add
1200–9600; a ki-guarded hit adds a lot; it decays over time [D/V].
Momentum blends the **smash charge rate** between two per-character values:
Goku 1.05 cold → 4.2 hot; roster median 1.1 → 4.0, up to 7 [D].

So the same charged smash that is too slow to use on a fresh opponent comes
out four times faster after seven or eight landed hits. Pressure snowballs,
routes change during a fight, and the defender feels the walls closing in
without any number on screen. We have nothing like it: our tenth exchange
plays exactly like our first.

*Measured: the effect is real but small and short. A neutral smash charged
in 0.70 s cold, 0.53 s 0.7 s after a 4-hit string, 0.63 s 1.2 s after it,
0.50 s right after 8 hits: 1.3–1.4×, not 4×. Either the gauge decays fast
or the rate does not blend linearly; worth copying as a nudge, not as the
snowball described above.*

## 5. No coin flips

- **Trades are decided by a priority byte** [V/D]: rush 1, rush ender 5,
  rush finishers 10, smashes 20, full smash 25, dash smash 30–40. Equal
  priority cancels both attacks with a camera shake. Ours: both get hit.
- **Rush versus rush is a mutual guard** [V]: a fighter in the first four
  steps of a string auto-guards incoming rush hits. Two players mashing
  produce chip and a reset, not a random winner.
- **Variety without randomness:** stagger animations cycle through four
  variants by a per-fighter counter [V]; nothing in the fighter core draws
  a random number. Hits look different every time and are still exactly
  reproducible.
- **Anti-loop by reaction, not by move** [V]: taking the same *special*
  reaction (heavy stagger, launch, bounce, ender stagger) twice in one
  combo turns the second into a push-back. Plain rush staggers are exempt,
  so strings never fail, only loops do.

## 6. Weight without hitstop

Ordinary hits have **zero** hitstop [V]. Weight comes from contrast,
all of it in the attack record [D]:

| | Jab | Rush ender | Smash (30%+) | Full smash |
|---|---|---|---|---|
| Camera shake power / time | 3 / 0.1 s | 3 / 0.2 s | 5 / 0.3 s | 7 / 0.3 s |
| Push on hit | 100 | 600–900 | blow-away | blow-away |
| Victim travel | sticks | staggers back | 1000–2000 for 0.5–1.7 s | same, farther |
| Damage (of a ~40000 pool [K]) | 300 | 580–970 | 1040 | 1290 (2260 for the held / just-frame full smash) |
| Ki gained | 650 | 650 | 2600 | 3900 |

- The light/heavy gap is **10–20× in travel** and more than 2× in shake,
  where ours is 4 vs 8 frames of freeze and a knockback of the same order.
- **The attacker moves into the hit** [V/D]: every rush step carries its
  own approach speed (700 on the first, 400 after; walking is 440) and
  homes on the victim until contact, then stops dead. Light hits barely
  push (100), so the pair stays glued and the string reads as one burst.
- **Landing matters:** a blown-away victim who hits the floor loses 500 HP
  and shakes the cameras; walls and the other fighter give their own crash
  reactions [V]. Recovery in the air is possible from frame 18 and costs
  1 ki bar [D].
- **The camera takes sides** [V]: an attack only gets its camera cut if the
  opponent is not attacking or started later; of two attackers the earlier
  one gets it, a tie gives none. The cut is a reward for initiative.
- Hitstop exists only where it means something: push-stop and counter
  guards, the full-smash wind-up (the victim is frozen while you load it),
  supers.
- A full combo does about 5% of a health pool (five rush hits: 1890). Rounds
  are long; one mistake is never the round. Ours: a jab is 3%.

## 7. Ki is fast to get and expensive to hold

- Charging is **quick**: Goku fills all five bars in 3.8 s, the roster
  median in 4.6 s [D]. (The first pass only had the code's minimum rate and
  concluded "slow". Ours is 6 s.) What makes charging a decision is not its
  speed but the wind-up and the fact that every strong option above costs
  something.
- Passive regeneration only refills to a per-character limit, 2 bars for
  most [D] (2400/s, so 8 s per bar), androids to full but they cannot
  charge.
- The attacker gains ki per hit (table above); the defender gains none.
- Prices: ki guard 1 bar per blocked hit, air recovery 1 bar, vanish behind
  1 bar, armour 0.1 bar, exhaustion at zero. Ki is spent on *defence*
  mistakes as much as on supers.

## 8. A roster of 161 on one moveset

Every character has the same 163 attack records, the same action ids, the
same inputs. Characters differ by scalars and flags [D]:

| | Min | Median | Max |
|---|---|---|---|
| Jab damage | 170 | 290 | 390 |
| Full smash damage | 720 | 1250 | 1740 |
| Throw damage | 230 | 1250 | 2500 |
| Damage taken | ×0.9 | ×1.0 | ×1.2 |
| Stagger scale on being hit | ×0.5 | ×1.0 | ×1.5 |
| Walk / dash speed | 18 / 73 | 44 / 118 | 64 / 147 |
| Ki charge (per second) | 150 | 21600 | 28500 |
| Jab first hit (frame, 60 Hz) | 2 | 12 | 38 |

plus skill bits (who has the vanishing step, the rush parry, the step-in,
blast deflect, which finisher sits on each string position) and body size.
Giants take half stagger, hit later and harder, and cannot be thrown.

Lesson for us: our Titan / Bulk / Sprite "profiles of the Brawler" are
exactly BT3's method, so "too little variety" is not a moveset-count
problem. BT3's variety is **situational**: which reaction the victim is in,
how hot the momentum is, where the wall and floor are, who is behind whom.

## 9. The CPU is a rule table playing a pad

- It only writes a virtual pad; rules are data: a 64-bit **situation word**
  (distance band, behind, incoming projectile, opponent downed or stunned,
  own gauge band, health thresholds) selects rule groups, and each rule is
  a weighted pick whose weights are a (level 0, level 29) pair [V].
- 32 **personality profiles** of rates share the same code [V].
- A "combo" action rolls each step over 11 weighted options (finisher,
  directional smash, guard + side step, dash, pause...), with the weight
  row chosen by the opponent's and its own state class [V]. That is why a
  BT3 CPU string is not the same string twice.
- Full-charge chance 10–50% by level, reaction delay 44–88 frames at the
  bottom to 0 at the top [V].

## What to take, in order of leverage

1. **Commitment by recovery, forgiveness by on-hit cancels** (§3), starting
   from BT3's real frame data instead of our picks: slower jabs, enders and
   smashes that are stuck for most of a second unless they land.
2. **The counter table** (§2): Z-counter against smashes only, ki guard at
   a real price, guard free against jabs.
3. **Dynamic range of impact** (§6): per-move shake, approach speed, push;
   no hitstop on lights; crash reactions; small damage per hit.
4. **Priority trades and rush auto-guard** (§5).
5. **Momentum** (§4).
6. Ki prices and regeneration limit (§7).

Not on the list any more: changing how light hitstun works. Ours is
already close to BT3's (§1).

How these become a plan, and which of our earlier decisions they reverse:
[gameplay_roadmap.md](gameplay_roadmap.md).

## Measured in the port

The PC port has test switches that play a recorded pad file with no window
and log both fighters' health and position every frame.
`tools/reference/bt3_script.py` writes the pad file from a small script
(its built-in prelude walks the menus to a 1P vs 2P duel), runs the game
for 25 seconds and prints every health change. Results of 2026-11-15:

| Test | Result |
|---|---|
| P1 walks in and mashes rush, P2 idle | 300, 300, 300, 410, 580 at +10, +16, +16, +14 frames; then the automatic follow-up (380) and more. Both start at **40000** health. Fighters in contact are 10.5 units apart. |
| P2 holds guard before the first hit | no damage at all (guard damage of rush hits is 0) |
| P2 holds guard from 2, 8 or 14 frames after the first hit, P1 keeps mashing | all five hits land |
| P1: one jab, second press 16 or 24 frames later (still chains), P2 guarding from 6 frames after the hit | second hit lands (14 and 22 frames after the first) |
| Same, second press 32 frames later (a new string) | lands on an idle P2, **blocked** by a guarding P2 |
| P1: one jab, then nothing. P2 mashes rush from 6 frames after being hit | P2's jab hits P1 30 frames after P2 was hit |

Caveats: one matchup, one distance, ground only; the fight's start moves
by a few frames between runs, so every test lets P1 arrive first and
times its presses from there.

### Second pass (2026-11-25): smashes, guard poses, Z-counter, momentum

`bt3_script.py --probe` runs the port under gdb and adds what the hash
line lacks, read from the port's own accessors: ki and blast stock, the
current action id, the stun timer and the smash charge (0..1). 70 runs,
same matchup (Goku Early mirror), P2 always on the pad. Frames below are
**60 Hz** (one fight pad frame is two). Ki: 20000 = one bar; both start
with 40000.

Smash = hold rush (□); the stick picks it: neutral (action 75), up (71),
down (72), side (73). It winds up ~16 frames, then charges 0 → full in
**0.70 s** (42 frames) cold, and hits ~8 frames after release. Full charge:
1290 damage (3.2% of health; 58% charge: 1040), attacker +3900 ki.

**Into each guard pose** (P2 holds guard from before the press; P = plain,
no ki; K n = ki guard costing n; U = unblockable, full damage; O =
push-off: the attacker recoils ~80 frames, the defender gains half a
blast stock and pays nothing):

| Smash | mid guard | stick-up guard | stick-down guard |
|---|---|---|---|
| neutral, 58% | P | K 9440 | K 9440 |
| neutral, full | P | K 11040 | K 11040 |
| side, 58% | P | K 9440 | K 9440 |
| side, full | K 11040 | **U** | **U** |
| up, 58% | P | **U** | P |
| up, full | K 10960 | **U** | O |
| down, 58% | P | P | **U** |
| down, full | K 18400 | O | **U** (+500 floor crash) |

§2's table holds, with two corrections: a ki guard costs **about half a
bar** (9440–11040; 18400 for a full down smash in mid guard), not a full
bar, and it grows with the charge; and the pose an up / down smash goes
through is the one on its own side (an up smash breaks the stick-up
guard).

| Test | Result |
|---|---|
| P2 jabs into P1's smash (full or 58%), five timings | a jab that lands first hits P1 (300) but P1 stays in the smash and it still lands in full; a later jab never connects. A smash under way shrugs off rush hits: it is not a trade. |
| Z-counter (guard press) against a full smash | pressed 2–8 frames before the hit: P2 vanishes (action 34), **0 damage, 0 ki**. 12 frames before: hit. |
| Z-counter against a jab, six timings | never vanishes: 2–4 frames before the hit it is a plain guard (0 damage), otherwise the jab lands. |
| Momentum: charge time after rush hits | cold 0.70 s (twice); 0.7 s after a 4-hit string 0.53 s; 1.2 s after it 0.63 s; right after 8 hits 0.50 s. **1.3–1.4× faster** and fading within about a second, not the 4× §4 expected. Smash damage unchanged. |
| Blow-away, full smashes on an idle P2 | neutral flies ~225 units in 0.9 s into a stage object (+500, bounces back); side flies ~240, crashes into the floor at the end (+500) and slides on to ~455; down crashes into the floor at once (+500) and slides ~230; up launches ~240 units high and lands without a crash. 58% neutral: a shorter flight, ~195 units, no crash. With no input the victim lies ~3 s and stands 4.5–7.4 s after the hit. |

Caveats as above, plus: actions are raw ids (named here from what they
do); "stick up" is the pad's up, which also walks toward the opponent; a
fighter idle for ~1.5 s plays an idle animation (action 67, ~1.6 s) that
swallows new presses, so scripts make P2 guard briefly first.

## Not verified

- World scale. Speeds are comparable to each other, not to our metres.
- Which animation event bit is the "next input" point: taken to be bit 3
  (it sits between the hit window opening and closing on every attack).
- Finisher and follow-up tables (in the common data file, not read).
- Ring edge: no blow-away reached one in these runs (the stage object on
  the neutral line is not the edge: the side smash went farther freely).
- Dash smash priority, two strings meeting (mutual guard), the paid
  teleport counter and vanish behind: not scripted yet.
- Recovery of a guarded or whiffed smash in frames (only seen roughly:
  P1 idle ~42 frames after a plain-guarded full smash).
