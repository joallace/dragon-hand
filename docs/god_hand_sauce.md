# God Hand: where the feel comes from

Second research pass (2026-11-15), companion to
[bt3_sauce.md](bt3_sauce.md). The rules and numbers already extracted are
in [god_hand_reference.md](god_hand_reference.md); this file is about why
they stay fun, and what they mean for a game where the opponent is another
fighter and not a crowd.

**How solid this is.** Much less than the BT3 file. The decomp
(https://github.com/LucasPicoli/god-hand-decomp, read at its 2026-11-12
state) went from 47% to 57% matched code, but most files are still named by
address and the player's dodge / cancel dispatcher is still not readable as
a system. This pass added little hard data. So the tags matter here:
**[V]** read in matching C (mostly from the October pass), **[M]** measured
in our PCSX2 captures, **[K]** how the game is known to play (my knowledge
of it, not checked in code: treat as a hypothesis until one of us confirms
it in PCSX2).

Mechanics in our own words; no decomp code.

## The short version

God Hand has no guard, no lock-on and no combo system worth the name. Its
depth is a **loop between the player's offence and the enemy's state**: the
enemy is always in one of a handful of readable states (attacking,
guarding, staggered, launched, dizzy, downed), each state has one best
answer, and good play is moving the enemy from state to state while never
standing where a hit lands. Fun comes from the *transitions*, and the game
gives each transition its own sound, slowdown and reward.

BT3's fun is in mutual guessing; God Hand's is in **reading and
converting**. They are compatible: BT3 supplies the versus rules, God Hand
supplies the texture of every single action.

## 1. Defence is a movement, never a state

- No guard exists in the player's code [V]. The only defences are the four
  right-stick dodges, walking out, and hitting first.
- Each dodge covers something different [M/K]: the **duck** (18f, re-chain
  every ~10f) keeps you in place and beats high strikes; the **side sway**
  (26f) beats straight attacks and moves you off line; the **backflip**
  (36f, 26f airborne) beats everything by distance but gives the turn away.
  They chain with no cap and no lockout [M].
- So a dodge is also a *positioning choice*: the best dodge is the one that
  leaves you in range to hit back. Ducking under a hook and answering in
  the same breath is the game's signature moment.
- Invulnerability is a timer the dodge states refresh, with a tail [V]. The
  exact windows are still unmeasured.

For us: our guard (BT3) and our dodges (God Hand) currently overlap as
"ways to not get hit". In God Hand's logic the dodge should be the
*aggressive* defence: it costs nothing, holds position, and is the only
defence that leads straight into your own hit, while guard is the safe,
passive one that costs ki against heavy hits (BT3 §2) and loses to throws.

## 2. Attacks announce themselves, then stop steering

- Enemy attacks **turn toward you during the wind-up (~5.6°/frame) and then
  lock** [V]: the charge grab picks a point, faces it and slides there in
  ~10 frames with no more tracking.
- Enemy recovery before acting again is long and level-scaled: 120 / 90 /
  60 / 30 frames + random 0–90 [V].
- Result: every hit you take is one you could have seen. This is the
  fairness contract that lets the game be brutally hard and still
  replayable.

We already track-then-lock (6°/frame, lock 2f before active). What we lack
is the **wind-up to read**: with 5-frame jabs there is nothing to see. BT3
agrees (median jab hits on frame 12, [bt3_sauce.md](bt3_sauce.md) §3).

## 3. The enemy's state decides your best move

[K] unless tagged. The loop that fills most of a God Hand fight:

| Enemy state | How it starts | Best answer |
|---|---|---|
| Attacking | their turn | dodge that keeps you in range, then hit |
| **Guarding** | they start blocking after eating a few hits of a string | a **guard break** move: slow, loses to a jab, but leaves them wide open |
| Guard broken / staggered | guard break, counter hit | your heaviest move or a launcher |
| Launched | launcher; **gravity is lower on the way down** (11.7 up, 7.0 down) [V] | juggle; send them into a wall or into other enemies |
| Dizzy | accumulated hits; 300f for the player, −10 per press [V] | context action: a mash **pummel** where mash rate sets the speed (×0.7–×2.0) [V] |
| Downed | knockdown | stomp, or reposition; they are invulnerable getting up (30f, refreshed) [V] |

- A plain string is therefore never the answer for long: enemies **guard
  it**, and the guard break that beats the guard is slow enough to lose to
  an enemy who is not guarding. That one rule stops the jab loop.
- A consecutive-hit counter caps at 4 [V] and the combo window is 90 frames
  [V]: the game counts hits in a string and changes behaviour on it.
- Counter hits (hitting an enemy during its attack) stagger harder [K]:
  aggression timed against a tell is the best damage in the game.

For us: BT3's "soft hitstun, guard comes up" (§1 there) and God Hand's
"enemies guard after a few hits, break it" are **the same idea** from two
directions. Both make the second half of a string a question instead of a
formality. It is the strongest point of agreement between the two games,
and the one our game is missing.

## 4. You build your own string

[K] The square-button chain is a row of slots; every technique you own can
go in any slot, and the triangle, cross and back/forward + button moves are
slots too. Fast jabs, slow guard breaks, launchers and kicks all cost a
slot, so a string is a statement: where the guard break sits decides how
you fight. Two players' Genes do not play alike.

This is the most direct answer either game has to "too little variety",
and it fits how our data is built: `CharacterDef` already lists a string
by role and `MoveData` is per move. A move pool plus a per-player string
loadout would give variety per *player* instead of per character, without
authoring new characters.

## 5. Risk is paid in visible currency

- **Tension** [V]: +1.5 for the first hit of a combo, +0.5 after; +12 for a
  taunt that angers an enemy; + damage ÷ max HP × 10 (cap 10) when you are
  hit. Starting exchanges and taking risks fill it; so does losing.
- **Taunt** [V]: unsafe, angers enemies in a cone, pays tension and level.
- **God Hand mode** costs exactly one bar and is invulnerable [V]; roulette
  moves run enemies at **10% speed** (3–20% at the impact) while you stay
  at full speed [V].
- **The level meter** [V]: +20 per hit, +50 per combo hit, +250 per taunt;
  −320 per hit taken, −1000 per knockdown. Higher level = faster enemies,
  shorter recoveries, more counters, and better rewards. The game speeds up
  when you play well and backs off when you do not, so the difficulty is
  always near your limit.

Lesson: the comeback and the power spike are *earned by visible risk*, and
the difficulty follows the player instead of being picked from a menu.

## 6. Impact

- **Hitstop is global**: one counter in the damage manager; while it runs,
  every object skips its tick [V]. Its length is still not found.
- **Speed is a global enemy multiplier** [V] re-applied every frame: big
  hits and special moves slow the *victim's world*, not the picture. The
  player keeps full speed, which reads as power instead of as lag.
- The camera sits close: 4 m back, chest height, narrow field of view [V].
  Every hit fills the screen. Two shake channels with their own decay [V].
- Strikes home (5.6°/frame, heavies 11°/frame for 20 frames) and lunge in
  proportion to the remaining distance, stopping ~1.1 m short [V]: you
  rarely whiff by a hair, and you never clip through.
- Big-hit effect on two hit types; launch heights from 0.6 to 7 m/s by hit
  type [V]: seven distinct launch strengths, where we have one knockback
  vector per move and a single gravity.

## 7. Enemies are written, not parameterised

The enemy idle chooser [V] is one long hand-written cascade: per enemy
type, per game level, a series of small dice (1 in 2, 1 in 3, 1 in 4, 1 in
6, 1 in 8) picking between circling, watching your attack, hopping away,
charging, a counted attack string, a special with its own 300-frame
cooldown. There is a "react" hook checked while the player attacks and a
"watch the target attack" step [V].

- Variety between enemies comes from **which options a type has at all**
  and how often, not from one brain with different sliders.
- Enemies have explicit *non-attacking* behaviours (circle, watch, hop
  away) that make their attacks events.
- Only one enemy may grab at a time [V]; the rest of the crowd pacing is
  emergent from long recoveries.

Our `CpuBrain` is the opposite: one 1700-line parametric brain, every
character and enemy the same mind at a different level. BT3's CPU sits in
between (data-driven rules and 32 personality profiles, bt3_sauce.md §9).
Both games agree that **personality is authored per type**.

## What to take, in order of leverage

1. **States that demand different answers** (§3): guard → guard break,
   launch → juggle, dizzy → pummel, downed → stomp or wait. Together with
   BT3's soft hitstun this is the cure for "same plan always wins".
2. **Tells** (§2): slower, readable startups on everything but the fastest
   jab, long level-scaled recoveries on CPU attacks.
3. **Dodge as the aggressive defence** (§1), clearly separated from guard.
4. **Authored opponent personalities** (§7) and a **level meter** (§5) for
   solo and co-op play.
5. **Victim slow-motion** instead of freezes for big hits (§6), floaty
   launches, more launch strengths, a closer camera.
6. **String loadouts** (§4) as the variety system.

How these become a plan: [gameplay_roadmap.md](gameplay_roadmap.md).

## Not verified, and how to verify

Everything tagged [K], plus: hitstop length, dodge startup and
invulnerability, counter-hit rules, after how many hits enemies guard, the
camera's behaviour on hit. None of these needs a recording with input
display: playing ten minutes of the first stage in PCSX2 and writing down
what happens answers most of them, and frame-stepping a save state answers
the rest.
