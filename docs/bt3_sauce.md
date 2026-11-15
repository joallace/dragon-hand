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

BT3's melee is not built on combos. It is built on **long, soft
advantage**: a hit gives the attacker a lot of time, but almost never takes
the defender's hands off the pad. Everything else (charge speed, guard
poses, priorities, ki prices, recoveries) is tuned around that one choice.
Our game made the opposite choice (short, hard hitstun), which is why the
same reference mechanics, added one by one, did not add up to the same game.

## 1. Soft hitstun: the defender keeps playing

- A light hit puts the victim in a **48-frame stagger** [D] (Goku's jab
  staggers are 24 frames `@30`; second-half rush hits use a 60-frame one).
  The attacker's jab hits on frame 8, can chain from frame 12 and ends at
  22. So a landed jab is worth about **+34** if you let it finish and +44
  from the chain point. Ours: hitstun 20, jab 20 long, about +5.
- But a light stagger **can be left by guarding** [V/I]: its handler keeps
  reading guard, the vanish-behind and the skill inputs every frame, and a
  staggered fighter holding guard also gets an instant "timed guard"
  against any hit flagged for it. That flag is on the **first hit of a rush
  string** and on **uncharged** smashes and finishers, on all 161
  characters [D]. Continuing an already-running string, or a smash charged
  past 30%, is not instant-guardable.
- Heavy reactions are the real stun: heavy stagger and ground bounce only
  accept the emergency escape and skills (mash speeds the animation up),
  stun is 30/60/90 frames with −6 per press, launches and blow-aways only
  allow recovery after 18 frames.

What this produces: every landed jab starts a **second guessing game**
instead of a movie. The attacker has a big window to choose (keep the
string, charge a smash, throw, step behind), the defender has an answer to
each. The interesting decisions happen *after* the first hit, which is
where ours has none (the defender's only out is a 2-bar vanish escape).

## 2. Every answer has a counter-answer

Read from the attack records of all 161 characters [D] plus the hit code
[V]:

| Attacker does | It beats | It loses to |
|---|---|---|
| Rush string (priority 1, enders 5) | anyone pressing buttons, steps, charging | plain guard (free, no ki); an opponent mid-rush auto-guards it |
| Smash, uncharged (priority 20) | rush (wins trades) | any guard pose (plain), instant guard, Z-counter |
| Up / down smash charged ≥30% | instant guard; **unblockable** against one of the two directional guard poses | the other two poses (plain), Z-counter |
| Side / neutral smash charged ≥30% | instant guard; the directional poses pay **1 ki bar** (ki guard) | mid guard (plain), Z-counter |
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

1. **Soft light hitstun + real heavy reactions** (§1). The single biggest
   structural difference between BT3 and us.
2. **The counter table** (§2): Z-counter against smashes only, ki guard at
   a real price, instant guard against string restarts.
3. **Commitment by recovery, forgiveness by on-hit cancels** (§3), starting
   from BT3's real frame data instead of our picks.
4. **Momentum** (§4).
5. **Priority trades and rush auto-guard** (§5).
6. **Dynamic range of impact** (§6): per-move shake, approach speed, push;
   no hitstop on lights; crash reactions.
7. Ki prices and regeneration limit (§7).

How these become a plan, and which of our earlier decisions they reverse:
[gameplay_roadmap.md](gameplay_roadmap.md).

## Not verified

- Health pools (the 16-byte base record in the common data was not read):
  "~40000" is from memory of the game.
- World scale. Speeds are comparable to each other, not to our metres.
- Exactly how guarding out of a light stagger feels in play (the code path
  is clear; the timing of the guard pose coming up is not measured). Worth
  ten minutes in the PC port before we copy it.
- Which animation event bit is the "next input" point: taken to be bit 3
  (it sits between the hit window opening and closing on every attack).
- Finisher and follow-up tables (in the common data file, not read).
