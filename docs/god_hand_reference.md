# God Hand: mechanics reference

How God Hand (PS2, Clover Studio / Capcom, 2006) plays under the hood. Use
this to steer the God Hand half of the game. The Tenkaichi half is in
[bt3_reference.md](bt3_reference.md); the side-by-side comparison and what
we already changed is in [reference_mechanics.md](reference_mechanics.md).
Why it stays fun is in [god_hand_sauce.md](god_hand_sauce.md).

Mechanics and numbers only, in our own words. Never copy code from the
decomp or the port (the game code belongs to Capcom; the port is GPL-3).

## Sources and how sure we are

- **First pass (2026-10-18):** the matching decompilation
  https://github.com/LucasPicoli/god-hand-decomp at ~47% matched. The
  player's dodge and cancel code was still raw asm then.
- **Third pass (2026-11-23):** three sources read together:
  - the decomp again (commit `4607c68`, 2026-11-22). Most of the player's
    states are now matched C, still mostly unnamed (`func_…`, `unk…`);
  - **God Hand: Rearmed** (https://github.com/God-Hand-Rearmed/God-Hand-Rearmed,
    commit `15dafc2`; binary v0.6.9.5 in `~/Downloads/God Hand Rearmed/`),
    a static recompilation to a native PC port. Its `docs/enemy-ai.md`,
    `docs/decomp/findings.md` and the comments in `src/kamite/` (60 FPS
    patches, game options) record what its authors read in the retail
    code and checked by running it;
  - the **retail boot ELF** (`SLUS_215.03`, extracted from your disc by the
    port into `game_data/`), disassembled here (llvm-objdump, mips3) for
    the functions the decomp still has as asm, and for constants in its
    data. The port's exe also carries a table of 4363 game-function names
    with their addresses. `python3 -I tools/reference/gh_disasm.py
    <address | name>` disassembles one function with those names
    (`--word <address>` prints a data word), to re-check anything below.
- Tags below: **[C]** read in code this pass (decomp C or our disassembly);
  **[R]** stated by the Rearmed authors, spot-checked here where marked;
  **[M]** measured in our PCSX2 captures. Untagged = first pass (matched C).
- Function addresses (`0x123938`…) are boot-ELF addresses, for re-checking.
- **Strike timing still lives in motion data**, not code: animation files
  raise event bits for the attack / dodge / move cancel windows, the charge
  point, the impact moment and the lunge marker. Per-move startup, active
  and cancel frames are therefore not in either repo (see [What the code
  still doesn't give](#what-the-code-still-doesnt-give)).

## Units and conversions

- **Game logic runs at 30 Hz** (fairly confident: save data counts play
  time "in frames at 30 fps"). A global frame-step scale multiplies every
  speed — the hook PCSX2's 60 fps patches use. Frame counts below are
  converted to **our 60 Hz** (×2) unless marked `@30`; per-frame speeds are
  converted to m/s (×30).
- **Units ≈ 1 m** (camera looks at 1.06 above the feet, a held object sits at
  1.6, grab range 3.0, melee "stop" radius ~1.1).
- State model: four bytes (mode / phase / step / step-arg); a state's step 0
  starts a motion, step 1 runs it to the end and returns to idle.
- The game logic really is 30 Hz [C/R]: the main loop waits on a
  vblanks-per-frame byte that is 2 at boot (PCSX2's and Rearmed's 60 FPS
  modes set it to 1 and then have to halve dozens of per-frame counters by
  hand, which is how the port's authors found most timers listed here).

## Controls: from the pad to an action [C]

Gene's mode-0 state table has 71 states (`0x3BD0F0`); modes 1 and 2 are
the hit / grabbed / death reactions. Almost every state calls one
**action chooser** (`func_00123938`) at the end of its tick, so input is
read in exactly one place.

**The input layer** (Gene's update, `func_00108AB0`) turns the pad into
small per-frame facts before any state runs:

| Fact | Rule |
|---|---|
| Left stick out | squared magnitude > 100 (of ±127 per axis, so past ~8%) |
| Left stick "just full" | crossed 10000 (~78%) this frame |
| Walk / run | stick out and within 70° of forward: walk below ~78%, run above; past 120° = turn round; 70–120° = turn in place (classic tank controls) |
| **Right stick dodge** | **edge**: true only on the frame the right stick leaves the ~8% deadzone. The direction is the stick angle on that frame. Re-arms when the stick goes back inside the deadzone |
| Face buttons, R1 | a press sets a byte to **3**, lowered by 1 a frame: each press stays buffered **3 game frames (6 of ours)** |
| **Dash** | the left stick hits "full" within ±60° of forward **twice within 10 game frames (20 of ours)**; the request is buffered 2 game frames |
| L1, L2, R2 | read straight from the pad's pressed edge (quick turn, taunt, God Hand), no buffer |

The **dodge has no buffer**: a flick that arrives while the current state
has no dodge window open is lost. Attacks have a 3-frame one.

**Cancel windows come from motion data.** Each motion raises three bits
while it plays: *attack cancel* (chain the string, start another attack),
*dodge cancel* and *move cancel* (end of recovery: walking, idle). The
chooser, called from inside a state, checks the bit for each family before
trying it; called from idle or walking it tries everything.

**Priority**, first match wins:

1. God Hand ending (meter empty) / starting (R2, full bar).
2. Roulette (R1, if an orb is owned).
3. Held object or weapon actions.
4. Stomp: a downed enemy within 0.5 m of Gene's height in reach.
5. Back attack: target 1.2–4 m away and the stick held back (>135°).
6. **Attack buttons** (needs the attack-cancel bit). The stick picks the
   slot: held back (>135°) selects another move set per button. Inside
   the duck's window an attack becomes the **duck counter**, right after
   a charged strike the **charge follow-up**, during a dash the **dash
   attack**.
7. Taunt (L2).
8. **Dodge** (right-stick edge, needs the dodge-cancel bit) or **dash**.
9. Quick turn (L1).
10. Movement (needs the move-cancel bit), else idle.

Attack beats dodge on the same frame, and a buffered attack beats a later
dodge flick.

**Right stick → dodge** (angle measured from straight up on the stick,
which with the classic camera is Gene's forward):

| Stick | Dodge | State |
|---|---|---|
| within ±45° of up | **duck** | own state (phase 7) |
| beyond ±135° (down) | **back-flip** | dodge state, variant 1 |
| left / right (the 90° either side) | **side sway** that way | dodge state, variants 2 / 3 |
| (left stick double-tap forward) | **dash** | dodge state, variant 0 |

## Dodges: read in code [C]

The dodge state (`func_0010CD38`, phase 6; the decomp still calls it a
"thrown-down step") and the duck (`0x10D0E0`, phase 7; named
`pl00_stepCountedAttack` there) are short. Each one starts its motion and
every frame turns Gene toward his target at π/16 rad (**11.25° a game
frame, 5.6° a frame of ours**, ~340°/s). It ends when the motion ends, or
earlier when the chooser accepts a new action inside one of the motion's
cancel windows.

**Invulnerability.** Gene's damage handler (`func_00109928`) ignores any
hit while the muteki timer (`+0x54C`, which the decomp calls `hitFlash`) is
above zero. The timer drops 1 per game frame (times the object's speed
rate). The dodges set it once, at the start, and never refresh it:

| Dodge | Invulnerable | Ours now |
|---|---|---|
| Side sway | **5 game frames = 10 of ours** | 12 |
| Back-flip | **12 game frames = 24 of ours** | 20 |
| Duck | **none** (see below) | 6 |
| Dash | none | none |

So most of a sway is **not** invulnerable. It works because the body
moves: Gene's whole hurtbox is **four 0.25 m spheres on bones** (made in
his init, `0x108200…`), and the sway's root motion (scaled ×1.2 for the
side sways) carries them out of the attack's volume.

**The duck is a hurtbox switch, not invulnerability** [C, R]. For its
first 8 game frames the duck sets a "low" flag that Gene's update reads
after his state runs. The flag lasts 2 frames, so the effect lasts about
**9 game frames = 0.3 s = 18 of ours** (Rearmed measured 9 game frames). While it is
set, **three of the four hurt spheres are off** (Rearmed: head and chest).
The fourth stays on, so anything aimed low still connects. Enemies
know it: the common enemy attack picker chooses one particular attack
(enemy phase `0x4B`) 1 time in 8 at any moment, always against a downed
Gene, and with an extra 50% against a ducking Gene, so **~56% when he
ducks** [C]. That it is a low attack (a stomp or sweep) is inferred from
its use on downed and ducking targets, not confirmed from its motion.

**The duck has a reward.** During those 8 frames the game looks for a live
enemy attack volume within 1.5 m of Gene's chest. If one was there, the
duck counts as **a combo hit**: +1.5 tension (+0.5 if a combo is already
running), +50 level points, the combo window refreshed. A
near-miss duck pays like landing a punch.

**Three duck poses**, picked at random but never the same twice in a row
(matches our G3 footage and `Fighter.duck_variant()`).

**Attacks out of a dodge** [C]:

- **Duck counter** (phase 13): an attack button inside the duck's window
  plays a dedicated counter strike. The head/chest spheres stay off until
  that strike's own attack-cancel point, so the counter cannot be
  stuffed by a high attack. It turns at 11.25° a game frame for up to
  50 game frames and lunges up to 0.5 m past a 1.2 m spacing (1 m with
  the stick held), with the lunge decaying ×0.9 a frame.
- **From a sway or back-flip**: no special move. The chooser simply
  accepts a normal attack once the motion's attack-cancel bit is up
  (our measured re-chain points, 26 / 30 frames, are those windows).
- **Dash** (variant 0 of the dodge state): for 12 game frames holding the
  stick queues the **dash attack** (phase 12); the run that follows a dash
  is a sprint.

No perfect-dodge rule exists in the player's dodge code: no timing window,
no slow-motion, no counter state [C]. The "perfect" reward is the duck's
near-miss combo hit, and the only counter is the duck counter.

**Charged strikes** (phase 14) [C]: at the motion's charge marker, a held
attack button drops Gene's motion and rate to **2.5%** and drains a charge
pool of 1.0 by 0.025 a game frame (**40 game frames = 80 of ours** at
most). The charge level climbs 0.05 a frame from 1.0 and gets +1 when the
pool runs dry, so it tops out at 4.0. Above 1.1 it plays a sound, above
2.5 the strike becomes its strong version (other damage and hit type, a
burst effect). For the first 10 frames of the strike's attack-cancel
window a button gives the **charge follow-up** (phase 15).

## Dodges: measured in PCSX2

From our own captures G1–G4 ([footage_capture.md](footage_capture.md)),
recorded 2026-10-18 with PCSX2's built-in capture: 640×480, 59.94 fps, no
dropped frames. Every game frame appears on exactly two video frames,
which confirms the **30 Hz logic**, so video frames = our 60 Hz frames and
every value below is a multiple of 2 (±2 accuracy). Gene at level 3
(not 1), no enemy near.

**No input display** in these clips, so all times start at **onset = the
first frame Gene moves**, not the button press. Startup (press → onset)
is still unmeasured (G5/G6 with an input display); invulnerability is now
read in code ([above](#dodges-read-in-code-c)). The follow camera sits behind Gene and re-frames after each
dodge, so travel distance can't be read either.

| Dodge | Reps | Phases (frames from onset) | Back to neutral | Earliest next dodge |
|---|---|---|---|---|
| **Back-sway** (back handspring toward the camera) | 6 + chain of 9 | crouch +2…+6, arms thrown up +8, inverted / hands down +10…+24, **feet land +26**, landing crouch +28…+30, upright +34…+36 | movement ends ~+44; turned back into the side-on stance ~+62 | **+30** (2 game frames after landing); the chained flip replays its full crouch, arms up at +38 |
| **Side-sway left** | 2 + 10 chained | blurred low lunge sideways +2…+10, rising +12…+14 | upright +16; facing forward again ~+30 | **≤ +26** |
| **Side-sway right** | 2 + 10 chained | blurred low lunge sideways +2…+14, rising +16…+20 | upright +22; facing forward again ~+30 | **≤ +26** |
| **Duck** | 5 + chain of ~15 | low pose +2…+10 (afterimage trail on the first frames), rising after | upright +16…+20 | **~+8…+10** |

Notes:

- **Every back-sway is frame-identical** (6/6 singles and all 9 chained
  hit the same landmarks to the frame) — a fixed animation, no variance.
- **Back-sway chain (G4):** 9 in a row, no cap and no lockout seen. Arms-up
  frames 54, 84, 114, 144, 176, 208, 240, 272, 304 → spacing 30, 30, 30,
  then 32 ×5. The 32s are probably slower mashing (one game frame late),
  so the earliest re-flip is **30 frames after the previous onset**. The
  last flip of the chain recovers like a single one.
- **Side sways (G2):** all 24 alternated L, R, L, R… (stick input unknown,
  so we can't tell whether that's forced or just how they were pressed).
  Chained sways are spaced exactly **26 frames** apart, every time (10 in a
  row) — consistent with a fixed cancel point at +26, after upright but
  before the forward-facing stance returns. Right sways lunge ~4 frames
  longer than left ones (consistent across reps).
- **Duck (G3):** three visibly different low poses — a deep curl to one
  side, a forward hunch, and a straight drop with the legs wide — that
  alternate between reps (random variants, or diagonal stick input; can't
  tell without input display). Mashed ducks (video frames 280–426) start a
  new duck every **8–10 frames** (onsets 280, 290, 300, 310, 320, 328, 336,
  …; mean ≈ 9.5), i.e. the duck is cancellable into another duck right as
  the low pose ends.
- Single-rep onsets (video frame numbers, for re-checking): G1 102, 214,
  320, 428, 554, 678 (518–552 is a camera swing); G2 56 L, 132 R, 206 L,
  278 R; G3 38, 70, 120, 168, 238.

**Ours now follows these** (`FighterTuning`, per direction): duck 18f
(chain from 10), side sway 26f (chain at 26), back-sway 36f (travels over
26f, chain from 30), no chain cap. Our invuln (6 / 12 / 20f from frame 1)
is still our own pick and always ends before the chain frame, so chains
stay punishable. God Hand's, now read in its code, differ: duck 0
(head/chest off ~18f, which outlasts its ~10f chain point), sway 10,
back-flip 24 ([Dodges: read in code](#dodges-read-in-code-c)); not adopted. Ducks pick one of three low poses after G3's (forward
hunch, curl to the left, wide-knee drop; `Fighter.duck_variant()`, never
the same twice in a row, chosen by a tick hash so every peer agrees) and
rise to stance after the chain frame. Previously one 24f dodge for all directions, chain from 16,
max 2 in a row.

## Invulnerability ("muteki")

- **A float countdown timer on the character** (`+0x54C`). Attacks and
  grabs simply skip a target whose timer is above zero. It drops by the
  object's speed rate each game frame, so a slowed enemy stays
  invulnerable longer.
- **Reaction states re-write the timer every frame they run**, so you are
  invulnerable for the whole state *plus* a tail after it ends. Values
  seen: 10f (hit and grab reactions, beatdowns), 30f (knockdown, get-up,
  God Hand on/off), 60f (roulette moves, taunt "sorry"), 4–6f for small
  cases. Normal strikes don't set it.
- **Dodges set it once, at the start** [C]: 10f for a sway, 24f for the
  back-flip, nothing for the duck and the dash ([details](#dodges-read-in-code-c)).
- The second defence tool is **switching hurt spheres off**: the duck and
  its counter strike [C].
- **God Hand mode** holds the timer at 5 game frames every frame it is on:
  invulnerable for the whole mode [C, R].
- No "perfect dodge" timing window, slow-motion or counter state exists in
  the dodge code [C].

## Knockdown, tech and get-up

- **Knockdown:** the player turns to face the attacker; pending damage lands
  on touchdown; invulnerable throughout (30f refreshed).
- **Tech:** inside the motion's tech window, a stick input (likely the right
  stick) or any face button switches to a quick-recovery state with a short
  invuln tail — that recovery state is probably the dodge/sway family.
- Otherwise the player lies down, then gets up (30f invuln, refreshed). A
  button pressed in the last ~20 frames turns it into a **wake-up attack**.
- **Flinches:** one of three random flinch motions; "can act" from when the
  invuln timer runs out; another flinch type has 20f invuln.

## Guard, grabs and enemy tracking

- **No player guard state** exists — defence is dodging.
- **Enemy grab** fails if the player is invulnerable, holding an object,
  more than **45° off** the enemy's facing, or more than 0.5 m higher/lower;
  succeeds within **3 m**.
- **Enemy charge-grab telegraph** — the pattern that makes dodges fair:
  1. Wind-up: the enemy **keeps turning toward the player** at ~5.6°/frame
     (11.25°/frame @30).
  2. Commit: it picks a point just behind the player, faces it instantly,
     and **slides there in ~10 frames with no more tracking**.
  3. Grab test at the end.
  Track during wind-up, lock at commit, short fast active phase.
- Other enemy turn rates: the same 5.6°/frame for 44 frames after a 30-frame
  delay; double that when re-facing during hit reactions.
- **Held by an enemy:** the enemy deals damage every 20 frames; mashing
  speeds up your escape animation from ×1 to ×3. Drain-holds also eat
  tension every frame and lower the level meter.

## Enemies as a group

Mostly from Rearmed's `docs/enemy-ai.md` [R], which reads the common
enemy's think code (`func_00208BE0`, `func_00211C08`, `func_00262AA8`); the
queue count and the global gates were re-read here [C]. Times converted to
our frames. Bosses and a few special kinds have their own choosers.

**No attack tokens, no camera.** Nothing hands out permission to attack.
Crowd pacing comes from three things every enemy works out for itself,
each update: its **place in a queue**, its **angle from Gene's facing**,
and its distance. The camera is never read: an enemy "off screen" is one
at Gene's side or back, measured from the way *he* faces.

**1. The queue.** An enemy's place = how many other enemies are nearer
Gene than it is (only those on roughly his floor: within 2 m of his
height) [C]. 0 = closest. In the Dark World every enemy counts 3 places
further back. On Level 1 an enemy that has sat in second place for ~5 s
acts as if first for 3 s (Level 2: third place), so a crowd rotates.
Each enemy also gets a spot around Gene in *his* frame: (0, 0), (±1, 1),
(±1.5, 1.5), (±2, 2): 3 spots on Levels 1–2, 5 on Level 3, 7 on DIE. The
spot is used only while the straight line to it is clear.

**2. How close it may come**, by place and level (m):

| Place | Level 1 | Level 2 | Level 3, DIE |
|---|---|---|---|
| 0 | 1.8 | 1.8 | 1.8 |
| 1 | 5 | 1.8 | 1.8 |
| 2 | 5 | 5 | 1.8 |
| 3–5 | 8 | 8 | 8 |
| 6+ | 12 | 12 | 12 |

- **The wedge:** an enemy in places 0–2 that stands 60° or more off
  Gene's facing never counts as arrived. It keeps walking to its spot,
  and within 4 m it **circles round him toward his front**. Close
  enemies drift into view before they act.
- **Making room:** once arrived and inside 3 m, every enemy past the first
  1 / 2 / 3 places (Levels 1 / 2 / 3) **steps back**; at DIE nobody does.
  Every 8 updates each enemy also checks for another enemy in its path
  (±60° of its facing) and walks round it.

**3. The attack decision** (runs first, every update, per enemy kind):

- **Point blank** (2.5 m, 2 m on Level 1): a random attack, **no facing
  check**. Standing next to an enemy is always dangerous.
- **Lunges** from 3–4 m (a few kinds 4–5 m or further): only inside a cone
  of **Gene's** facing: none on Level 1, ±45° Level 2, ±60° Level 3, ±90°
  DIE. Then that enemy waits **10 s** before lunging again.
- **Held at his back:** outside a cone of Gene's facing (±60° Level 1, ±90°
  Level 2, ±135° Level 3, ±180° DIE) a countdown runs and the enemy does
  not attack while it lasts. Attacks from straight behind exist only at
  DIE.
- **Nobody starts an attack while Gene is held** [C]: a grab sets a
  manager flag every frame it holds him, and the common attack decision
  bails out (after a couple of special-case checks) while it is set. One grab at a time (first pass).
- **Same floor** [C]: many attack picks need the enemy within 0.1 m of
  Gene's height.
- **Answers to Gene's state** [C]: a **ducking** Gene draws one specific
  attack (the one always used on a downed Gene, likely low) ~56% of the
  time instead of 1 in 8. The duck has a counter.

**Stun gauge** [R]: hits add to a per-enemy stun value that decays by 30
every 90 game frames; at 200 it resets and the enemy is **stunned for 150
game frames (5 s)**, counted down by its own speed rate (slow-motion
stretches it). That is the "dizzy" state the beatdowns and punishes feed
on (Rearmed's optional "Sway Bar" draws it).

**Joint attacks** [C, from the decomp's manager header]: one special
five-enemy group (enemy numbers `0x270`–`0x274`) has manager-run phases
for a **pair attack** (the enemy beside Gene and its partner), a
**surround** formation, a second **formation** and a **line-up**, each
starting with a 300-game-frame (10 s) timer. Group tactics in God Hand
are hand-authored set pieces, not emergent.

**Difficulty is mostly positioning.** Between Level 1 and DIE the attacks
themselves barely change. What changes is how many enemies may stand close
(1 → 3), how wide the lunge cone is (0° → ±90°), how far round his back
they may attack from (±60° → all round), and whether they back off.
Recovery and reaction speeds also scale (first pass). Hard is simply DIE
all game.

**What Rearmed changed** [R]: with a wider screen (16:9 or a larger
field of view), the wedge and the cones are widened in proportion to how
much further round Gene the picture reaches, so enemies at the new screen
edges behave like on-screen ones. With its free camera turned away from
Gene, the enemies take the *camera's* yaw as his facing (and his own
facing at point blank). Their lesson: the cones exist to keep attacks
**visible**, so they must follow what the player can see.

## Tension and God Hand mode

- **Gauge size:** 120 + 30 per tension item (120–270). Display tiers below
  50% / up to 75% / above. "God Hand ready" = one full bar (120).
- **Gains:**
  - Landing a hit: **+1.5 on the first hit of a combo, +0.5 on later hits**
    (halved at the top level). The combo window is 90 frames.
  - **Taunting** an enemy into anger: +12.
  - Throws/holds on enemies: +0.5 to +1 per hit.
  - **Taking damage:** + damage ÷ max HP × 10, capped at 10.
  - ×1.25 on Easy. **No gain while God Hand mode is active.**
- **Tension-boost orb move:** 1 orb = +30, 2 orbs = +80; slows enemies to
  10% speed and gives 60f invuln.
- **God Hand activation:** invulnerable throughout; at the motion event the
  mode turns on and the gauge's *floor* is set to current − 120 — **one
  activation costs exactly one bar**, the rest is protected. Turning it off
  has its own short invulnerable motion.
- **Starting it** [C, R]: R2 with a full bar, from any state whose motion
  allows an attack cancel (it is the chooser's first test). **Invulnerable
  for the whole mode** (the timer is held at 5 game frames every frame).
- **While active** the gauge drains **0.4 a game frame (12 a second)**
  [C], times Gene's own speed rate, so **one bar lasts 10 s** (Rearmed timed 1.2 s → 12.3 s for a run
  from full). The drain is ×0.25 during beatdown prompts and stops during
  grab / punish moves played in sync with an enemy; reaching the floor ends
  the mode at the top of the chooser (an end pose with 3 game frames of
  invulnerability). The damage/speed boost itself is still not found
  (attack power is the likely carrier).

## Roulette moves

- Orbs are the God Reel slots. An orb seems to be spent **only when the move
  first connects** — a whiff may be free (moderate confidence).
- About 19 roulette states share a template: 60f invuln (refreshed), enemies
  can't act, tension drain paused, the arm wrap comes off and goes back on,
  a motion camera.
- **Enemies run at 10% speed for the whole move** (dropping to 3–20% at the
  impact marker) while the player runs at full speed. The slow-mo is a
  global enemy speed multiplier re-applied every frame.
- Flat damage examples: 80–230, 400, 700. Ordinary strikes deal
  attack power × 10 / 15 / 20.

## Strikes, combos and reactions

- **Strike template:** homing turn ~5.6°/frame for up to 100 frames
  (heavies: ~11°/frame for 20 frames); lunge proportional to the remaining
  distance (more if the stick is held), decaying each frame; forward motion
  stops within ~1.1 m (1.4 for some moves) of the target. The player's HP
  can't drop below 1 during their own attacks.
- **Hold-to-charge:** at the charge marker, holding slows the animation to
  2.5% speed while a charge pool drains (80 frames max); past a threshold
  the hit gets a damage bonus and effect ([details](#dodges-read-in-code-c)).
- **Combo counter** [C]: each hit (and each near-miss duck) adds one;
  the combo stays open 45 game frames (90 of ours) after the last one. The
  5th hit plays a sound and gives +100 level points; every hit gives +50.
- **Hitstop** [C, R]: one counter in the damage manager. While it runs the
  damage manager skips its step (no hit tests, the muteki timers don't
  drop) and Gene's update and the common enemy update also check it, so it
  is a real freeze. It is started with one of two lengths, *Gene hit
  someone* / *Gene was hit*, read from two words of game data
  (`0x3BF190` / `0x3BF194`). Both are **0 in the boot ELF image**, and
  no boot-ELF code writes them directly (a block copy can't be ruled out).
  Gene's update returns before its input layer while the counter runs, so
  pad edges during a hitstop are lost and the button buffers freeze. Rearmed treats the counter as live,
  so they are probably filled at run time from disc data.
  **Measured (2026-11-25, [below](#measured-in-rearmed)): both words are
  still 0 in RAM mid-fight**, and the counter never ran on any hit
  (Gene's punches, his △ heavy, his × kick, or the thugs hitting him):
  ordinary hits have **no hitstop**, as in BT3.
- **Enemy launches** (vertical speed by hit type, m/s): 3.9, 1.17, 7.0, 5.46
  (3.9 on some), 2.73, 0.59, 1.95 — ×1.1 for heavy enemy types, ×0.7 for
  some others. **Gravity is asymmetric: ~11.7 m/s² rising, ~7.0 m/s²
  falling** — launches float on the way down. Two hit types trigger the
  big-hit effect. A consecutive-hit counter caps at 4.
- **Enemy stun after landing from a knockdown,** by level meter: 0 / 1/8 /
  1/4 / 1/4 / 1/2. Stunned enemies get 20f invuln.
- **Enemy recovery before acting:** 120 / 90 / 60 / 30 frames + random 0–90
  (by level); a 1/3 chance of a fast 40-frame recovery flagged to counter;
  then each frame a small chance to counter-attack if the player is close.
- **Beatdowns** on a dizzy enemy: QTE-style mash loops of at least 180
  frames where mash rate sets the animation speed (×0.7 … ×2.0) — faster
  mashing = more hits.
- **The mash meter** (beatdowns, grab escapes, death crawl): measure the gap
  between face-button presses; a gap under the tier's limit goes up a tier,
  over it goes down. Limits shrink from 18 to 4 frames by tier. No press for
  20 frames drops a tier every 10 frames. Tier = animation speed.
- **Player dizzy:** a 300-frame timer, −10 per face-button press (plus a
  larger amount for another input, unidentified).
- **Damage taken:** × level factor 0.6 / 0.8 / 1.0 / 1.0 / 1.2, ×0.5 on Easy
  else ×0.75, further reduced by an unidentified counter. **Guts rule:** a
  hit that would kill leaves 1 HP if you had at least 11.

## Taunts and the level meter

- **Taunt:** one of two motions; at its event it angers enemies in a cone
  (radius 15 m, ±30°). Angering any: +12 tension and +250 level points.
- **"Sorry" move:** spends an orb, 60f invuln, pacifies enemies and **resets
  the level to 1** when it ends.
- **Level meter (dynamic difficulty)**: Level 1, 2, 3 and **DIE** at
  1000 / 3000 / 4000 / 5000 points; the fourth level is skipped [R, table
  checked here]. **Easy** caps the points at Level 2; **Hard** starts at DIE
  and the meter never moves, so Hard is Level DIE all game [R].
  - Points: +20 per strike landed, +50 per combo hit (near-miss ducks
    included), +100 on a 5th hit, +100 per beatdown, +250 per taunt; −160
    or −320 per hit taken by damage type [C], −1000 for heavy hits /
    knockdowns.
  - Gains scale down as the level rises (×1.5 … ×0.5); losses don't.
  - "Grace": reaching a level grants a buffer that absorbs one drop.
  - Higher levels speed enemies up, raise their stun/counter odds and
    shorten their recovery (above).

## Camera

- Normal follow: target slightly to one side at chest height (−0.2, 1.06),
  ~4° pitch, distance 4 m, FOV 31 (unit/axis unconfirmed).
- A separate lock-on chase mode exists (unmatched).
- **Shake:** two sinusoidal channels, each decaying per frame; per-hit values
  are unmatched.
- Roulette and God Hand moves use authored motion cameras.

## What the code still doesn't give

- **Per-move frame data** (startup, active, the three cancel windows, the
  charge marker): motion files on the disc. Readable with Rearmed's own
  tools (its F2 debug menu shows motions and hit volumes; `src/kamite/
  mot_edit.cpp` parses the format) or by frame-stepping a save state.
  Measured so far: the first punch of the □ combo only
  ([below](#measured-in-rearmed)); `tools/reference/ghr_script.py` does
  the rest the same way.
- ~~Hitstop length~~: measured, 0 on ordinary hits ([below](#measured-in-rearmed)).
  Whether special hits (roulette, God Hand mode, guard breaks) set the two
  words is untested.
- **God Hand mode's damage / speed boost.**
- **Which bone the duck leaves hittable** (sphere on bone 23 of Gene's
  skeleton; Rearmed calls the other three head and chest).
## Measured in Rearmed

Rearmed's **test mode** loads a save state, plays a pad recording and
writes one CSV row per 60 Hz frame with Gene's and every enemy's state,
HP, motion and motion frame, and the hitstop counter.
`tools/reference/ghr_script.py` drives it headless with the native Linux
AppImage (v0.6.9.6; the script format is in its docstring, worked out from
the port's error messages). All runs below start from one save state: the
first fight (two thugs in front, four enemies in the room), **Hard** (level
DIE all game), 60 FPS mode, default techniques. Frames are 60 Hz.

| Test | Result |
|---|---|
| Gene's □ combo into the thugs | hits for 4–6; **no freeze**: Gene's and the thug's motion frames keep advancing through contact; Gene's animation slows from 0.75 to 0.5 motion frames per frame after the hit, the thug's reaction starts at once |
| △ (slow heavy, lands for 24) | no freeze either |
| × kick (10) | a single held frame on both sides |
| Hitstop counter (`hitstop` column) | 0 on every frame of every run, including the thugs hitting Gene (100 → 9 in 10 s standing still on Hard) |
| The two hitstop length words (`0x3BF190` / `0x3BF194`, read from the save state's RAM) | 0 and 0 mid-fight |
| □ punch 1 → punch 2 (second press at different delays) | punch 1 lasts 34 frames on its own. A press 4 frames in is buffered and punch 2 starts at punch 1's frame 12; presses 12–24 frames in start punch 2 four frames after the press; from ~28 frames in it no longer chains (punch 1 finishes, then a new punch 1). The chain works **on a whiff**. |

Caveats: one save state, one enemy type, Hard, only the first combo link
timed; motion ids are raw addresses (Gene's punch 1 `DC2560`, punch 2
`DB7E20`, punch 3 `DC35E0`, △ `DC62A0`, × `E14A20`).

## Where we stand

| God Hand mechanic | Us |
|---|---|
| Right-stick sways / duck / back-sway | ✅ lengths and chains match the [PCSX2 measurements](#dodges-measured-in-pcsx2) |
| Dodge invulnerability: sway 10f, back-flip 24f, set once at the start | ≈ sway 12f, back 20f (from frame 1) |
| Duck = head/chest hurt volumes off ~18f, **no** invulnerability; the fourth sphere stays hittable | ✗ duck is 6f invuln + a lower capsule (0.9 m); no attack is "low" |
| Dodge fires on the stick leaving an ~8% deadzone; **no dodge buffer** | ✗ flick at 75%, re-arm under 35%, buffered 6f |
| Attack buffer 3 game frames | ✅ 6f (`input_buffer_frames`) |
| Dash: double-tap to ~78% forward within 20f | ≈ 14f window, 60% threshold |
| Dodges keep turning toward the target (5.6°/f) | partial: the side sway orbits the target, but facing isn't re-aimed during a dodge |
| Near-miss duck = a combo hit (tension, level, combo timer) | ≈ perfect dodge (any dodge, first 4f) gives ki 15 + a 30f counter window ×1.5 |
| Duck counter: an attack in the duck window = a special strike that keeps head/chest off | ≈ duck kick (HEAVY in a duck from 7f) |
| No perfect-dodge slow-mo / freeze | ✗ we freeze 6f on a perfect dodge and stagger the attacker 40f on a perfect duck |
| Invuln as state + tail | ✅ in effect (dodge invuln, wake-up tail) |
| Attacks track in startup, lock at commit | ✅ (6°/frame, lock 2f before active) |
| Tech out of knockdowns | ✅ air tech, quick rise, rolls |
| Dodge chaining / dodge → attack | ✅ |
| Hold-to-charge strikes (80f pool, motion at 2.5%) + follow-up window | ✅ charge; no follow-up |
| Hitstop freeze | ✅ 4 / 8 global (GH length still a runtime value) |
| Tension gauge → God Hand mode (one bar = 10 s, invulnerable) | merged into ki by design; no mode |
| Tension (ki) from taking damage, scaled by damage | ✗ flat +3 |
| Taunts | ✅ TAUNT (RT): 50f, +1 ki bar when finished, ×1.25 damage taken meanwhile |
| Roulette moves with opponent slow-mo | partial (ultimate freeze; no slow-mo) |
| Floaty asymmetric launch gravity | ✅ since 2026-11-23: knocked-down fighters fall at 14.4 m/s² (0.6 of our 24, GH's ratio); juggle hits pop them to ≥4.5 m/s with 0.35 of the horizontal push, cap 4 juggle hits (GH's consecutive-hit cap) |
| Upper hook juggle starter | ✅ forward + Y (neutral or mid-string) launches; X follows up in the air |
| Enemies answer a ducking Gene with their low attack (~56%) | ✅ CPU: mid-string HEAVY vs a duck it has seen goes low (sweep) at `cpu.duck_low_chance` (0.2 → 0.56 by level), else mid; never the launcher |
| Stun gauge (200, decays) → dizzy 5 s + beatdown mash | partial (staggers, no gauge, no mash) |
| Mash meter for escapes | ✗ |
| Guts (1 HP) rule | ✗ |
| Wake-up attack | ✅ LIGHT on the ground = get-up strike |
| Level meter (dynamic difficulty) | ✗ (CPU levels are fixed) |
| Crowd: distance queue, approach rings, wedge to the front, back-hold cones by level, no attacks while grabbed | partial: co-op attack tokens (2 melee / 1 ranged per player), grab lock, optional off-screen rule by facing cone |

## Steering toward God Hand

Ideas that would make the game read more "God Hand", roughly by payoff.
None are scheduled; pick consciously, since some pull against Tenkaichi.

1. **Dodges by geometry, not invulnerability.** Copy the code's split:
   a short invulnerable start (sway 10f, back-flip 24f), then the dodge's
   own travel does the rest; the duck switches the upper hurt volume off
   for ~18f instead of being invulnerable, and gains a weakness: **low
   attacks** (a move flag) still hit a ducking fighter. This gives the
   CPU an answer to duck spam, as God Hand's enemies have.
2. **Reward the near miss, not a timing window.** Replace or join the
   perfect-dodge rule with God Hand's: a duck (or any dodge) that ends with
   an enemy attack volume within ~1.5 m pays like a landed hit (ki, combo
   timer). No freeze: the reward is the free turn.
3. **Dodge input:** fire on the stick leaving a small deadzone and read the
   direction there (lower `flick_threshold`), and consider dropping the
   dodge buffer (GH has none, attacks keep 6f). Test both on a pad first:
   a lower threshold also fires on sloppy thumb rests.
4. **Crowd rules for co-op** (see [Enemies as a group](#enemies-as-a-group)):
   approach rings by queue place, the wedge that walks flankers to the
   front, back-hold cones that widen with the level, no new attacks while a
   player is grabbed, a 10 s lunge cooldown. Could replace or sit under
   the token system: tokens limit *how many* attack, God Hand's rules decide
   *who and from where*.
5. *(Implemented 2026-11-23, fall side only.)* **Floaty launches:** lower falling gravity than rising gravity for
   knocked-down fighters (GH ≈ 0.6 ratio), so juggles have hang time.
6. **Opponent slow-mo instead of freezes** for supers/ultimate: run the
   victim at 10% for the move's duration while the attacker stays at full
   speed (deterministic: a per-fighter speed scale in the sim).
7. **Stun gauge → dizzy → beatdown:** hits fill a decaying gauge (200,
   −30 per 90 game frames); full = 5 s dizzy, opened with a mash finisher.
8. **Ki from damage taken scaled by damage** (dmg ÷ max HP × 10 style), and a
   first-hit bonus on ki gained from hitting — rewards opening hits.
9. *(Implemented: ki reward, punishable.)* **Taunt** button.
10. **Guts rule** (a killing hit leaves 1 HP once) for comeback drama.
11. **Level meter for the CPU:** an optional single-player / co-op mode
    where the level rises while you play well; in God Hand it mostly moves
    *positioning* rules (who may come close, from which angle), not damage.
