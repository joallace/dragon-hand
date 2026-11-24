# Animation roadmap

Follows the pilot (commit 8a1f64b: `PoseSprings`, `MoveTracks` for jab /
jab2 / hook / kick / heavy, idle and walk life, hit kicks; feel in
`data/tuning/anim.tres`). Presentation only throughout: nothing here touches
the sim, save_state or the wire. Each step is one commit, tested on its own.

Ground rules carried over from the pilot:
- A strike's contact pose puts its fist/foot on the move's hitbox center
  (`MoveTracks.CONTACTS`, checked by `tests/move_tracks_test`); key poses keep
  the feet planted like idle unless the move leaves the floor.
- The strike arrives on the first active frame, accelerating (EASE_IN);
  anticipation before, overshoot + hold + settle after.
- Signs: torso/head +X tilts BACK; torso +Y turns the chest left (right
  shoulder forward); limbs +X swing forward. The old POSES were written with
  the torso pitch inverted in places; step 1 fixes the ones still in use.
- Check by eye with `tools/pose_sheet.tscn` (strips); fit contacts with
  `tools/pose_fit.tscn`.

## Step 1: fix the static poses + fitting tool (done)
- Audit every pose still in `FighterVisual.POSES` (state poses: guard,
  hitstun, dash, charge, throw hold/toss, taunt, recoil, ducks, sways...)
  for the inverted lean; fix them, keeping the floor/duck tests green.
- Drop dead poses (`kick_high*`: no move uses it).
- `tools/pose_fit.tscn`: the pilot's throwaway fitter as a tool (searches a
  limb's angles to reach a move's hitbox, reports the floor offset).

## Step 2: tracks for the remaining ground strikes (done, with step 3)
finisher (string ender / counter / rush finish), kick_mid, smash_left,
smash_right, hammer, uppercut, charge_kick, kick_low (sweep), dash_punch
(also the rush), belly_bump, throw. Contacts fitted and tested.

## Step 3: tracks for air, floor and ki moves (done)
jump_kick, dive_kick (airborne: no floor check, contact only), duck_kick,
getup_kick (keeps its procedural spin), ki_blast and beam (no hitbox: the
hands aim at the spawn point; beam holds through its long recovery).

## Step 4: state tracks (done: sways, backflip, charge, hitstun zones, bounce)
Generalize tracks to non-attack states on their own state-frame timeline:
dodges (sways, duck, backflip), dash start/travel/stop, guard enter, hitstun
by height and side (head snap vs body fold), launch -> fall -> knockdown ->
wakeup, charge enter/loop/release, taunt, throw hold/toss, thrown.

## Step 5: richer rig (Blender model + rig joints) (done: chest, wrists, ankles)
Split torso into pelvis/spine/chest, add neck, wrists and ankles (maybe a
clenched-fist bone). `tools/blender/build_fighter.py` + `FighterModel` bone
mapping + `FighterVisual._build_rig`; new joints default to 0 so every pose
stays valid, then poses/tracks gain hip rotation separate from the chest,
wrist snap on punches, ankle roll on pivots. `visual_pose_test` /
`move_tracks_test` re-run against the new model.

## Step 6: procedural polish
Foot planting (two-bone IK on the legs so planted feet don't skate while
turning or lunging), head look-at on the target, hitstop shake on the
victim, landing squash, ki aura pulse with the breathing.
