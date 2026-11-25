# Frame data (generated)

Written by `tools/frame_data_sheet.tscn` on 2026-11-25 from `data/moves`
and each character's tuning. Rerun it after changing moves or tuning, then
put this header back:

    godot --headless res://tools/frame_data_sheet.tscn -- out=docs/frame_data.md

Conventions are in `tools/frame_data.gd`: "hit on" is the first active
frame (60 Hz, counted from 1); advantage = stun - (active + recovery), with
contact on the first active frame, no mashing and no cancels;
`tests/frame_data_test` holds that formula to the sim. BT3 numbers to
compare with: [bt3_sauce.md](bt3_sauce.md) §3 and "Measured in the port".

Guard m/h/l: P plain, K ki guard, O push-off, S push-stop, U unblockable.

### Brawler

| move | role | height | hit on | active | recovery | total | damage | dmg % | on hit | adv hit | guard stun | adv guard | adv push-off | guard m/h/l | ki guard %bar | push | lift | hitstop hit/guard | cancel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| brawler_jab1 | light 1 | mid | 6 | 3 | 12 | 20 | 30.0 | 3.0 | stun 20 | +5 | 10 | -5 | - | PPP | - | 1.5 | 0.0 | 4/4 | 7-19 brawler_jab2 brawler_finisher_1 brawler_upper_hook brawler_sweep; super |
| brawler_jab2 | light 2 | mid | 6 | 3 | 12 | 20 | 30.0 | 3.0 | stun 20 | +5 | 10 | -5 | - | PPP | - | 1.5 | 0.0 | 4/4 | 7-19 brawler_hook brawler_finisher_2 brawler_upper_hook brawler_sweep; super |
| brawler_hook | light 3 | mid | 8 | 3 | 14 | 24 | 40.0 | 4.0 | stun 22 | +5 | 10 | -7 | - | PPP | - | 2.0 | 0.0 | 4/4 | 9-23 brawler_kick brawler_finisher_3 brawler_upper_hook brawler_sweep; super |
| brawler_kick | light 4 | mid | 10 | 4 | 18 | 31 | 45.0 | 4.5 | stun 26 | +4 | 10 | -12 | - | PPP | - | 2.0 | 0.0 | 4/4 | 11-27 brawler_ender brawler_finisher_4 brawler_upper_hook brawler_sweep; super |
| brawler_ender | light 5 | mid | 11 | 4 | 24 | 38 | 55.0 | 5.5 | stagger 34 | +6 | 14 | -14 | - | PPP | - | 4.5 | 0.0 | 8/4 | 12-33 brawler_finisher brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_1 |  | mid | 10 | 4 | 22 | 35 | 50.0 | 5.0 | stagger 30 | +4 | 18 | -8 | -2 | SKK | 35.0 | 1.0 | 0.0 | 8/4 | 13-31 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_1_charged |  | mid | 14 | 4 | 22 | 39 | 50.0 | 5.0 | stagger 30 | +4 | 18 | -8 | - | KKK | 35.0 | 7.5 | 5.0 | 8/4 | 16-34 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_1_charged @full |  | mid | 14 +45 held | 4 | 22 | 39 | 90.0 | 9.0 | KD | - | crash 75 | +49 | - | KKK | - | 7.5 | 5.0 | 8/4 | 16-34 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_2 |  | mid | 11 | 4 | 24 | 38 | 60.0 | 6.0 | stagger 28 | 0 | 18 | -10 | -2 | SKK | 35.0 | 5.5 | 0.0 | 8/4 | 13-31 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_2_charged |  | mid | 15 | 4 | 24 | 42 | 60.0 | 6.0 | stagger 28 | 0 | 18 | -10 | - | KKK | 35.0 | 7.5 | 5.0 | 8/4 | 17-35 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_2_charged @full |  | mid | 15 +45 held | 4 | 24 | 42 | 108.0 | 10.8 | KD | - | crash 75 | +47 | - | KKK | - | 7.5 | 5.0 | 8/4 | 17-35 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_3 |  | mid | 11 | 4 | 24 | 38 | 65.0 | 6.5 | stagger 36 | +8 | 18 | -10 | -2 | SKK | 35.0 | 1.5 | 0.0 | 8/4 | 13-31 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_3_charged |  | mid | 15 | 4 | 24 | 42 | 65.0 | 6.5 | stagger 36 | +8 | 18 | -10 | - | KKK | 35.0 | 7.5 | 5.0 | 8/4 | 17-35 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_3_charged @full |  | mid | 15 +45 held | 4 | 24 | 42 | 117.0 | 11.7 | KD | - | crash 75 | +47 | - | KKK | - | 7.5 | 5.0 | 8/4 | 17-35 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_4 |  | mid | 12 | 4 | 26 | 41 | 70.0 | 7.0 | stagger 42 | +12 | 18 | -12 | -2 | SKK | 35.0 | 1.0 | 0.0 | 8/4 | 13-31 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_4_charged |  | mid | 16 | 4 | 26 | 45 | 70.0 | 7.0 | stagger 42 | +12 | 18 | -12 | - | KKK | 35.0 | 7.5 | 5.0 | 8/4 | 18-36 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_4_charged @full |  | mid | 16 +45 held | 4 | 26 | 45 | 126.0 | 12.6 | KD | - | crash 75 | +45 | - | KKK | - | 7.5 | 5.0 | 8/4 | 18-36 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher | finisher | mid | 11 | 4 | 26 | 40 | 85.0 | 8.5 | KD | - | 18 | -12 | -2 | SKK | 35.0 | 6.5 | 6.0 | 8/4 | 13-31 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_charged |  | mid | 15 | 4 | 26 | 44 | 85.0 | 8.5 | KD | - | 18 | -12 | - | KKK | 35.0 | 7.5 | 5.0 | 8/4 | 17-35 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_finisher_charged @full |  | mid | 15 +45 held | 4 | 26 | 44 | 153.0 | 15.3 | KD | - | crash 75 | +45 | - | KKK | - | 7.5 | 5.0 | 8/4 | 17-35 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_upper_hook | heavy_high | high | 13 | 4 | 24 | 40 | 65.0 | 6.5 | KD | - | 18 | -10 | -2 | KOU | 30.0 | 0.6 | 8.5 | 8/4 | 14-37 brawler_jab1 (on contact); super |
| brawler_upper_hook_charged |  | high | 17 | 4 | 24 | 44 | 65.0 | 6.5 | KD | - | 18 | -10 | - | KKU | 30.0 | 0.6 | 10.5 | 8/4 | 19-37 brawler_jab1 (on contact); super |
| brawler_upper_hook_charged @full |  | high | 17 +45 held | 4 | 24 | 44 | 117.0 | 11.7 | KD | - | crash 75 | +47 | - | KKU | - | 0.6 | 10.5 | 8/4 | 19-37 brawler_jab1 (on contact); super |
| brawler_sweep | heavy_low | low | 14 | 4 | 26 | 43 | 60.0 | 6.0 | KD | - | 18 | -12 | -2 | KUO | 25.0 | 1.5 | 3.0 | 8/4 | 15-33 brawler_jab1 brawler_upper_hook (on contact); super |
| brawler_sweep_charged |  | low | 18 | 4 | 26 | 47 | 60.0 | 6.0 | KD | - | 18 | -12 | - | KUK | 25.0 | 3.0 | 4.0 | 8/4 | 20-38 brawler_jab1 brawler_upper_hook (on contact); super |
| brawler_sweep_charged @full |  | low | 18 +45 held | 4 | 26 | 47 | 108.0 | 10.8 | KD | - | crash 75 | +45 | - | KUK | - | 3.0 | 4.0 | 8/4 | 20-38 brawler_jab1 brawler_upper_hook (on contact); super |
| brawler_kick_mid | heavy | mid | 15 | 4 | 22 | 40 | 75.0 | 7.5 | stagger 36 | +10 | 20 | -6 | 0 | OKK | 45.0 | 2.5 | 0.0 | 8/4 | 17-35 brawler_jab1 brawler_upper_hook brawler_sweep (on contact); super |
| brawler_charge_punch |  | mid | 19 | 4 | 24 | 46 | 55.0 | 5.5 | stun 26 | -2 | 16 | -12 | - | KKK | 15.0 | 6.5 | 3.5 | 8/4 | super |
| brawler_charge_punch @full |  | mid | 19 +45 held | 4 | 24 | 46 | 121.0 | 12.1 | KD | - | crash 75 | +47 | - | KKK | - | 6.5 | 3.5 | 8/4 | super |
| brawler_smash_up |  | high | 19 | 4 | 24 | 46 | 55.0 | 5.5 | stun 26 | -2 | 16 | -12 | - | KKU | 15.0 | 1.5 | 9.5 | 8/4 | super |
| brawler_smash_up @full |  | high | 19 +45 held | 4 | 24 | 46 | 121.0 | 12.1 | KD | - | crash 75 | +47 | - | KKU | - | 1.5 | 9.5 | 8/4 | super |
| brawler_smash_down |  | low | 19 | 4 | 24 | 46 | 55.0 | 5.5 | stun 26 | -2 | 16 | -12 | - | KUK | 15.0 | 1.0 | -4.0 | 8/4 | super |
| brawler_smash_down @full |  | low | 19 +45 held | 4 | 24 | 46 | 121.0 | 12.1 | KD | - | crash 75 | +47 | - | KUK | - | 1.0 | -4.0 | 8/4 | super |
| brawler_smash_left |  | mid | 19 | 4 | 24 | 46 | 55.0 | 5.5 | stun 26 | -2 | 16 | -12 | - | KKK | 15.0 | 2.0 | 1.5 | 8/4 | super |
| brawler_smash_left @full |  | mid | 19 +45 held | 4 | 24 | 46 | 121.0 | 12.1 | KD | - | crash 75 | +47 | - | KKK | - | 2.0 | 1.5 | 8/4 | super |
| brawler_smash_right |  | mid | 19 | 4 | 24 | 46 | 55.0 | 5.5 | stun 26 | -2 | 16 | -12 | - | KKK | 15.0 | 2.0 | 1.5 | 8/4 | super |
| brawler_smash_right @full |  | mid | 19 +45 held | 4 | 24 | 46 | 121.0 | 12.1 | KD | - | crash 75 | +47 | - | KKK | - | 2.0 | 1.5 | 8/4 | super |
| brawler_charge_kick |  | mid | 21 | 4 | 26 | 50 | 70.0 | 7.0 | stagger 36 | +6 | 20 | -10 | - | KKK | 20.0 | 6.0 | 0.0 | 8/4 | super |
| brawler_charge_kick @full |  | mid | 21 +60 held | 4 | 26 | 50 | 140.0 | 14.0 | stagger 60 | +30 | crash 75 | +45 | - | KKK | - | 6.0 | 0.0 | 8/4 | super |
| brawler_jump_kick | jump_attack | mid | 7 | 8 | 10 | 24 | 50.0 | 5.0 | stun 24 | +6 | 12 | -6 | - | PPU | - | 3.0 | 0.0 | 4/4 |  |
| brawler_dive_kick | jump_heavy | mid | 9 | 12 | 12 | 32 | 65.0 | 6.5 | KD | - | 16 | -8 | - | KKU | 25.0 | 4.0 | 3.0 | 8/4 |  |
| brawler_duck_kick | duck_heavy | low | 7 | 4 | 18 | 28 | 55.0 | 5.5 | KD | - | 12 | -10 | -8 | KUO | 20.0 | 1.5 | 2.5 | 8/4 | super |
| brawler_getup_kick | getup_attack | low | 7 | 10 | 20 | 36 | 45.0 | 4.5 | KD | - | 12 | -18 | -8 | KUO | 15.0 | 4.0 | 3.0 | 8/4 |  |
| brawler_dash_punch | dash_attack | mid | 7 | 5 | 18 | 29 | 60.0 | 6.0 | KD | - | 14 | -9 | - | KKK | 20.0 | 6.0 | 3.0 | 8/4 |  |
| brawler_throw | throw | mid | 6 | 3 | 28 | 36 | 90.0 | 9.0 | KD | - | - | - | - | throw | - | 5.5 | 5.0 | 8/4 |  |
| brawler_counter | counter | mid | 4 | 4 | 22 | 29 | 70.0 | 7.0 | KD | - | 16 | -10 | -4 | OKK | 20.0 | 3.0 | 7.0 | 8/4 | super |
| brawler_ki_blast | ki_blast | mid | shot 9 | 0 | 16 | 24 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| brawler_ki_blast_shot | shot of brawler_ki_blast | mid | - | - | - | - | 25.0 | 2.5 | stun 16 | - | 8 | - | - | PPP | - | 2.0 | 0.0 | 3/3 | - |
| brawler_ki_blast_charged |  | mid | shot 11 | 0 | 20 | 30 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| brawler_ki_blast_charged @full |  | mid | shot 11 +30 held | 0 | 20 | 30 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| brawler_ki_blast_charged_shot | shot of brawler_ki_blast_charged | mid | - | - | - | - | 60.0 | 6.0 | KD | - | 14 | - | - | KKK | 20.0 | 6.0 | 4.0 | 8/4 | - |
| brawler_rush | super1 | mid | 9 | 6 | 30 | 44 | 40.0 | 4.0 | stun 40 | chain | 12 | -24 | - | KKK | 100.0 | 0.5 | 0.0 | 3/3 | auto brawler_rush_2 on hit |
| brawler_rush_2 |  | mid | 4 | 2 | 6 | 11 | 35.0 | 3.5 | stun 30 | chain | 12 | +4 | - | KKK | 15.0 | 0.5 | 0.0 | 3/3 | auto brawler_rush_3 on hit |
| brawler_rush_3 |  | mid | 4 | 2 | 6 | 11 | 35.0 | 3.5 | stun 30 | chain | 12 | +4 | - | KKK | 15.0 | 0.5 | 0.0 | 3/3 | auto brawler_rush_4 on hit |
| brawler_rush_4 |  | mid | 4 | 2 | 6 | 11 | 35.0 | 3.5 | stun 30 | chain | 12 | +4 | - | KKK | 15.0 | 0.5 | 0.0 | 3/3 | auto brawler_rush_finish on hit |
| brawler_rush_finish |  | mid | 7 | 3 | 28 | 37 | 120.0 | 12.0 | KD | - | 12 | -19 | - | KKK | 15.0 | 9.0 | 8.0 | 14/4 |  |
| brawler_beam | super2 | mid | shot 19 | 0 | 80 | 98 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| brawler_beam_shot | shot of brawler_beam | mid | - | - | - | - | 18.0 | 1.8 | stun 18 | - | 12 | - | - | KKK | 12.0 | 1.0 | 0.0 | 1/1 | - |
| brawler_ultimate | ultimate | mid | shot 31 | 0 | 120 | 150 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| brawler_ultimate_shot | shot of brawler_ultimate | mid | - | - | - | - | 22.0 | 2.2 | stun 18 | - | 14 | - | - | KKK | 25.0 | 1.0 | 0.0 | 1/1 | - |

### Titan

| move | role | height | hit on | active | recovery | total | damage | dmg % | on hit | adv hit | guard stun | adv guard | adv push-off | guard m/h/l | ki guard %bar | push | lift | hitstop hit/guard | cancel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| titan_jab1 | light 1 | mid | 8 | 3 | 16 | 26 | 39.0 | 3.9 | stun 20 | +1 | 10 | -9 | - | PPP | - | 1.5 | 0.0 | 4/4 | 9-24 titan_jab2 titan_finisher_1 titan_upper_hook titan_sweep; super |
| titan_jab2 | light 2 | mid | 8 | 3 | 16 | 26 | 39.0 | 3.9 | stun 20 | +1 | 10 | -9 | - | PPP | - | 1.5 | 0.0 | 4/4 | 9-24 titan_hook titan_finisher_2 titan_upper_hook titan_sweep; super |
| titan_hook | light 3 | mid | 10 | 3 | 18 | 30 | 52.0 | 5.2 | stun 22 | +1 | 10 | -11 | - | PPP | - | 2.0 | 0.0 | 4/4 | 11-30 titan_kick titan_finisher_3 titan_upper_hook titan_sweep; super |
| titan_kick | light 4 | mid | 13 | 4 | 23 | 39 | 58.5 | 5.85 | stun 26 | -1 | 10 | -17 | - | PPP | - | 2.0 | 0.0 | 4/4 | 14-35 titan_ender titan_finisher_4 titan_upper_hook titan_sweep; super |
| titan_ender | light 5 | mid | 14 | 4 | 31 | 48 | 71.5 | 7.15 | stagger 34 | -1 | 14 | -21 | - | PPP | - | 4.5 | 0.0 | 8/4 | 15-43 titan_finisher titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_1 |  | mid | 13 | 4 | 29 | 45 | 65.0 | 6.5 | stagger 30 | -3 | 18 | -15 | -2 | SKK | 40.3 | 1.0 | 0.0 | 8/4 | 17-40 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_1_charged |  | mid | 18 | 4 | 29 | 50 | 65.0 | 6.5 | stagger 30 | -3 | 18 | -15 | - | KKK | 40.3 | 7.5 | 5.0 | 8/4 | 21-44 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_1_charged @full |  | mid | 18 +45 held | 4 | 29 | 50 | 117.0 | 11.7 | KD | - | crash 75 | +42 | - | KKK | - | 7.5 | 5.0 | 8/4 | 21-44 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_2 |  | mid | 14 | 4 | 31 | 48 | 78.0 | 7.8 | stagger 28 | -7 | 18 | -17 | -2 | SKK | 40.3 | 5.5 | 0.0 | 8/4 | 17-40 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_2_charged |  | mid | 19 | 4 | 31 | 53 | 78.0 | 7.8 | stagger 28 | -7 | 18 | -17 | - | KKK | 40.3 | 7.5 | 5.0 | 8/4 | 22-45 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_2_charged @full |  | mid | 19 +45 held | 4 | 31 | 53 | 140.4 | 14.04 | KD | - | crash 75 | +40 | - | KKK | - | 7.5 | 5.0 | 8/4 | 22-45 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_3 |  | mid | 14 | 4 | 31 | 48 | 84.5 | 8.45 | stagger 36 | +1 | 18 | -17 | -2 | SKK | 40.3 | 1.5 | 0.0 | 8/4 | 17-40 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_3_charged |  | mid | 19 | 4 | 31 | 53 | 84.5 | 8.45 | stagger 36 | +1 | 18 | -17 | - | KKK | 40.3 | 7.5 | 5.0 | 8/4 | 22-45 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_3_charged @full |  | mid | 19 +45 held | 4 | 31 | 53 | 152.1 | 15.21 | KD | - | crash 75 | +40 | - | KKK | - | 7.5 | 5.0 | 8/4 | 22-45 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_4 |  | mid | 15 | 4 | 34 | 52 | 91.0 | 9.1 | stagger 42 | +4 | 18 | -20 | -2 | SKK | 40.3 | 1.0 | 0.0 | 8/4 | 17-40 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_4_charged |  | mid | 21 | 4 | 34 | 58 | 91.0 | 9.1 | stagger 42 | +4 | 18 | -20 | - | KKK | 40.3 | 7.5 | 5.0 | 8/4 | 23-47 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_4_charged @full |  | mid | 21 +45 held | 4 | 34 | 58 | 163.8 | 16.38 | KD | - | crash 75 | +37 | - | KKK | - | 7.5 | 5.0 | 8/4 | 23-47 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher | finisher | mid | 14 | 4 | 34 | 51 | 110.5 | 11.05 | KD | - | 18 | -20 | -2 | SKK | 40.3 | 6.5 | 6.0 | 8/4 | 17-40 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_charged |  | mid | 19 | 4 | 34 | 56 | 110.5 | 11.05 | KD | - | 18 | -20 | - | KKK | 40.3 | 7.5 | 5.0 | 8/4 | 22-45 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_finisher_charged @full |  | mid | 19 +45 held | 4 | 34 | 56 | 198.9 | 19.89 | KD | - | crash 75 | +37 | - | KKK | - | 7.5 | 5.0 | 8/4 | 22-45 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_upper_hook | heavy_high | high | 17 | 4 | 31 | 51 | 84.5 | 8.45 | KD | - | 18 | -17 | -2 | KOU | 34.5 | 0.6 | 8.5 | 8/4 | 18-48 titan_jab1 (on contact); super |
| titan_upper_hook_charged |  | high | 22 | 4 | 31 | 56 | 84.5 | 8.45 | KD | - | 18 | -17 | - | KKU | 34.5 | 0.6 | 10.5 | 8/4 | 24-48 titan_jab1 (on contact); super |
| titan_upper_hook_charged @full |  | high | 22 +45 held | 4 | 31 | 56 | 152.1 | 15.21 | KD | - | crash 75 | +40 | - | KKU | - | 0.6 | 10.5 | 8/4 | 24-48 titan_jab1 (on contact); super |
| titan_sweep | heavy_low | low | 18 | 4 | 34 | 55 | 78.0 | 7.8 | KD | - | 18 | -20 | -2 | KUO | 28.7 | 1.5 | 3.0 | 8/4 | 19-43 titan_jab1 titan_upper_hook (on contact); super |
| titan_sweep_charged |  | low | 23 | 4 | 34 | 60 | 78.0 | 7.8 | KD | - | 18 | -20 | - | KUK | 28.7 | 3.0 | 4.0 | 8/4 | 26-49 titan_jab1 titan_upper_hook (on contact); super |
| titan_sweep_charged @full |  | low | 23 +45 held | 4 | 34 | 60 | 140.4 | 14.04 | KD | - | crash 75 | +37 | - | KUK | - | 3.0 | 4.0 | 8/4 | 26-49 titan_jab1 titan_upper_hook (on contact); super |
| titan_kick_mid | heavy | mid | 19 | 4 | 29 | 51 | 97.5 | 9.75 | stagger 36 | +3 | 20 | -13 | 0 | OKK | 51.7 | 2.5 | 0.0 | 8/4 | 22-45 titan_jab1 titan_upper_hook titan_sweep (on contact); super |
| titan_charge_punch |  | mid | 24 | 4 | 31 | 58 | 71.5 | 7.15 | stun 26 | -9 | 16 | -19 | - | KKK | 17.3 | 6.5 | 3.5 | 8/4 | super |
| titan_charge_punch @full |  | mid | 24 +45 held | 4 | 31 | 58 | 157.3 | 15.73 | KD | - | crash 75 | +40 | - | KKK | - | 6.5 | 3.5 | 8/4 | super |
| titan_smash_up |  | high | 24 | 4 | 31 | 58 | 71.5 | 7.15 | stun 26 | -9 | 16 | -19 | - | KKU | 17.3 | 1.5 | 9.5 | 8/4 | super |
| titan_smash_up @full |  | high | 24 +45 held | 4 | 31 | 58 | 157.3 | 15.73 | KD | - | crash 75 | +40 | - | KKU | - | 1.5 | 9.5 | 8/4 | super |
| titan_smash_down |  | low | 24 | 4 | 31 | 58 | 71.5 | 7.15 | stun 26 | -9 | 16 | -19 | - | KUK | 17.3 | 1.0 | -4.0 | 8/4 | super |
| titan_smash_down @full |  | low | 24 +45 held | 4 | 31 | 58 | 157.3 | 15.73 | KD | - | crash 75 | +40 | - | KUK | - | 1.0 | -4.0 | 8/4 | super |
| titan_smash_left |  | mid | 24 | 4 | 31 | 58 | 71.5 | 7.15 | stun 26 | -9 | 16 | -19 | - | KKK | 17.3 | 2.0 | 1.5 | 8/4 | super |
| titan_smash_left @full |  | mid | 24 +45 held | 4 | 31 | 58 | 157.3 | 15.73 | KD | - | crash 75 | +40 | - | KKK | - | 2.0 | 1.5 | 8/4 | super |
| titan_smash_right |  | mid | 24 | 4 | 31 | 58 | 71.5 | 7.15 | stun 26 | -9 | 16 | -19 | - | KKK | 17.3 | 2.0 | 1.5 | 8/4 | super |
| titan_smash_right @full |  | mid | 24 +45 held | 4 | 31 | 58 | 157.3 | 15.73 | KD | - | crash 75 | +40 | - | KKK | - | 2.0 | 1.5 | 8/4 | super |
| titan_charge_kick |  | mid | 27 | 4 | 34 | 64 | 91.0 | 9.1 | stagger 36 | -2 | 20 | -18 | - | KKK | 23.0 | 6.0 | 0.0 | 8/4 | super |
| titan_charge_kick @full |  | mid | 27 +60 held | 4 | 34 | 64 | 182.0 | 18.2 | stagger 60 | +22 | crash 75 | +37 | - | KKK | - | 6.0 | 0.0 | 8/4 | super |
| titan_jump_kick | jump_attack | mid | 9 | 8 | 13 | 29 | 65.0 | 6.5 | stun 24 | +3 | 12 | -9 | - | PPU | - | 3.0 | 0.0 | 4/4 |  |
| titan_dive_kick | jump_heavy | mid | 11 | 12 | 16 | 38 | 84.5 | 8.45 | KD | - | 16 | -12 | - | KKU | 28.7 | 4.0 | 3.0 | 8/4 |  |
| titan_duck_kick | duck_heavy | low | 9 | 4 | 23 | 35 | 71.5 | 7.15 | KD | - | 12 | -15 | -8 | KUO | 23.0 | 1.5 | 2.5 | 8/4 | super |
| titan_getup_kick | getup_attack | low | 9 | 10 | 26 | 44 | 58.5 | 5.85 | KD | - | 12 | -24 | -8 | KUO | 17.3 | 4.0 | 3.0 | 8/4 |  |
| titan_dash_punch | dash_attack | mid | 9 | 5 | 23 | 36 | 78.0 | 7.8 | KD | - | 14 | -14 | - | KKK | 23.0 | 6.0 | 3.0 | 8/4 |  |
| titan_throw | throw | mid | 8 | 3 | 36 | 46 | 117.0 | 11.7 | KD | - | - | - | - | throw | - | 5.5 | 5.0 | 8/4 |  |
| titan_counter | counter | mid | 5 | 4 | 29 | 37 | 91.0 | 9.1 | KD | - | 16 | -17 | -4 | OKK | 23.0 | 3.0 | 7.0 | 8/4 | super |
| titan_ki_blast | ki_blast | mid | shot 11 | 0 | 21 | 31 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| titan_ki_blast_shot | shot of titan_ki_blast | mid | - | - | - | - | 32.5 | 3.25 | stun 16 | - | 8 | - | - | PPP | - | 2.0 | 0.0 | 3/3 | - |
| titan_ki_blast_charged |  | mid | shot 14 | 0 | 26 | 39 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| titan_ki_blast_charged @full |  | mid | shot 14 +30 held | 0 | 26 | 39 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| titan_ki_blast_charged_shot | shot of titan_ki_blast_charged | mid | - | - | - | - | 78.0 | 7.8 | KD | - | 14 | - | - | KKK | 23.0 | 6.0 | 4.0 | 8/4 | - |
| titan_rush | super1 | mid | 11 | 6 | 39 | 55 | 52.0 | 5.2 | stun 40 | chain | 12 | -33 | - | KKK | 115.0 | 0.5 | 0.0 | 3/3 | auto titan_rush_2 on hit |
| titan_rush_2 |  | mid | 5 | 2 | 8 | 14 | 45.5 | 4.55 | stun 30 | chain | 12 | +2 | - | KKK | 17.3 | 0.5 | 0.0 | 3/3 | auto titan_rush_3 on hit |
| titan_rush_3 |  | mid | 5 | 2 | 8 | 14 | 45.5 | 4.55 | stun 30 | chain | 12 | +2 | - | KKK | 17.3 | 0.5 | 0.0 | 3/3 | auto titan_rush_4 on hit |
| titan_rush_4 |  | mid | 5 | 2 | 8 | 14 | 45.5 | 4.55 | stun 30 | chain | 12 | +2 | - | KKK | 17.3 | 0.5 | 0.0 | 3/3 | auto titan_rush_finish on hit |
| titan_rush_finish |  | mid | 9 | 3 | 36 | 47 | 156.0 | 15.6 | KD | - | 12 | -27 | - | KKK | 17.3 | 9.0 | 8.0 | 14/4 |  |
| titan_beam | super2 | mid | shot 24 | 0 | 104 | 127 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| titan_beam_shot | shot of titan_beam | mid | - | - | - | - | 23.4 | 2.34 | stun 18 | - | 12 | - | - | KKK | 13.8 | 1.0 | 0.0 | 1/1 | - |
| titan_ultimate | ultimate | mid | shot 40 | 0 | 156 | 195 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| titan_ultimate_shot | shot of titan_ultimate | mid | - | - | - | - | 28.6 | 2.86 | stun 18 | - | 14 | - | - | KKK | 28.7 | 1.0 | 0.0 | 1/1 | - |

### Bulk

| move | role | height | hit on | active | recovery | total | damage | dmg % | on hit | adv hit | guard stun | adv guard | adv push-off | guard m/h/l | ki guard %bar | push | lift | hitstop hit/guard | cancel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bulk_jab1 | light 1 | mid | 7 | 3 | 14 | 23 | 30.0 | 3.0 | stun 20 | +3 | 10 | -7 | - | PPP | - | 1.5 | 0.0 | 4/4 | 8-22 bulk_jab2 bulk_finisher_1 bulk_upper_hook bulk_sweep; super |
| bulk_jab2 | light 2 | mid | 7 | 3 | 14 | 23 | 30.0 | 3.0 | stun 20 | +3 | 10 | -7 | - | PPP | - | 1.5 | 0.0 | 4/4 | 8-22 bulk_hook bulk_finisher_2 bulk_upper_hook bulk_sweep; super |
| bulk_hook | light 3 | mid | 9 | 3 | 17 | 28 | 40.0 | 4.0 | stun 22 | +2 | 10 | -10 | - | PPP | - | 2.0 | 0.0 | 4/4 | 10-27 bulk_kick bulk_finisher_3 bulk_upper_hook bulk_sweep; super |
| bulk_kick | light 4 | mid | 12 | 4 | 21 | 36 | 45.0 | 4.5 | stun 26 | +1 | 10 | -15 | - | PPP | - | 2.0 | 0.0 | 4/4 | 13-32 bulk_ender bulk_finisher_4 bulk_upper_hook bulk_sweep; super |
| bulk_ender | light 5 | mid | 13 | 4 | 28 | 44 | 55.0 | 5.5 | stagger 34 | +2 | 14 | -18 | - | PPP | - | 4.5 | 0.0 | 8/4 | 14-39 bulk_finisher bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_1 |  | mid | 12 | 4 | 26 | 41 | 50.0 | 5.0 | stagger 30 | 0 | 18 | -12 | -2 | SKK | 38.5 | 1.0 | 0.0 | 8/4 | 15-36 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_1_charged |  | mid | 16 | 4 | 26 | 45 | 50.0 | 5.0 | stagger 30 | 0 | 18 | -12 | - | KKK | 38.5 | 7.5 | 5.0 | 8/4 | 19-40 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_1_charged @full |  | mid | 16 +45 held | 4 | 26 | 45 | 90.0 | 9.0 | KD | - | crash 75 | +45 | - | KKK | - | 7.5 | 5.0 | 8/4 | 19-40 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_2 |  | mid | 13 | 4 | 28 | 44 | 60.0 | 6.0 | stagger 28 | -4 | 18 | -14 | -2 | SKK | 38.5 | 5.5 | 0.0 | 8/4 | 15-36 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_2_charged |  | mid | 18 | 4 | 28 | 49 | 60.0 | 6.0 | stagger 28 | -4 | 18 | -14 | - | KKK | 38.5 | 7.5 | 5.0 | 8/4 | 20-41 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_2_charged @full |  | mid | 18 +45 held | 4 | 28 | 49 | 108.0 | 10.8 | KD | - | crash 75 | +43 | - | KKK | - | 7.5 | 5.0 | 8/4 | 20-41 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_3 |  | mid | 13 | 4 | 28 | 44 | 65.0 | 6.5 | stagger 36 | +4 | 18 | -14 | -2 | SKK | 38.5 | 1.5 | 0.0 | 8/4 | 15-36 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_3_charged |  | mid | 18 | 4 | 28 | 49 | 65.0 | 6.5 | stagger 36 | +4 | 18 | -14 | - | KKK | 38.5 | 7.5 | 5.0 | 8/4 | 20-41 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_3_charged @full |  | mid | 18 +45 held | 4 | 28 | 49 | 117.0 | 11.7 | KD | - | crash 75 | +43 | - | KKK | - | 7.5 | 5.0 | 8/4 | 20-41 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_4 |  | mid | 14 | 4 | 31 | 48 | 70.0 | 7.0 | stagger 42 | +7 | 18 | -17 | -2 | SKK | 38.5 | 1.0 | 0.0 | 8/4 | 15-36 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_4_charged |  | mid | 19 | 4 | 31 | 53 | 70.0 | 7.0 | stagger 42 | +7 | 18 | -17 | - | KKK | 38.5 | 7.5 | 5.0 | 8/4 | 21-42 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_4_charged @full |  | mid | 19 +45 held | 4 | 31 | 53 | 126.0 | 12.6 | KD | - | crash 75 | +40 | - | KKK | - | 7.5 | 5.0 | 8/4 | 21-42 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher | finisher | mid | 13 | 4 | 31 | 47 | 85.0 | 8.5 | KD | - | 18 | -17 | -2 | SKK | 38.5 | 6.5 | 6.0 | 8/4 | 15-36 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_charged |  | mid | 18 | 4 | 31 | 52 | 85.0 | 8.5 | KD | - | 18 | -17 | - | KKK | 38.5 | 7.5 | 5.0 | 8/4 | 20-41 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_finisher_charged @full |  | mid | 18 +45 held | 4 | 31 | 52 | 153.0 | 15.3 | KD | - | crash 75 | +40 | - | KKK | - | 7.5 | 5.0 | 8/4 | 20-41 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_upper_hook | heavy_high | high | 15 | 4 | 28 | 46 | 65.0 | 6.5 | KD | - | 18 | -14 | -2 | KOU | 33.0 | 0.6 | 8.5 | 8/4 | 16-43 bulk_jab1 (on contact); super |
| bulk_upper_hook_charged |  | high | 20 | 4 | 28 | 51 | 65.0 | 6.5 | KD | - | 18 | -14 | - | KKU | 33.0 | 0.6 | 10.5 | 8/4 | 22-43 bulk_jab1 (on contact); super |
| bulk_upper_hook_charged @full |  | high | 20 +45 held | 4 | 28 | 51 | 117.0 | 11.7 | KD | - | crash 75 | +43 | - | KKU | - | 0.6 | 10.5 | 8/4 | 22-43 bulk_jab1 (on contact); super |
| bulk_sweep | heavy_low | low | 16 | 4 | 31 | 50 | 60.0 | 6.0 | KD | - | 18 | -17 | -2 | KUO | 27.5 | 1.5 | 3.0 | 8/4 | 18-39 bulk_jab1 bulk_upper_hook (on contact); super |
| bulk_sweep_charged |  | low | 21 | 4 | 31 | 55 | 60.0 | 6.0 | KD | - | 18 | -17 | - | KUK | 27.5 | 3.0 | 4.0 | 8/4 | 23-45 bulk_jab1 bulk_upper_hook (on contact); super |
| bulk_sweep_charged @full |  | low | 21 +45 held | 4 | 31 | 55 | 108.0 | 10.8 | KD | - | crash 75 | +40 | - | KUK | - | 3.0 | 4.0 | 8/4 | 23-45 bulk_jab1 bulk_upper_hook (on contact); super |
| bulk_kick_mid | heavy | mid | 18 | 4 | 26 | 47 | 75.0 | 7.5 | stagger 36 | +6 | 20 | -10 | 0 | OKK | 49.5 | 2.5 | 0.0 | 8/4 | 20-41 bulk_jab1 bulk_upper_hook bulk_sweep (on contact); super |
| bulk_charge_punch |  | mid | 22 | 4 | 28 | 53 | 55.0 | 5.5 | stun 26 | -6 | 16 | -16 | - | KKK | 16.5 | 6.5 | 3.5 | 8/4 | super |
| bulk_charge_punch @full |  | mid | 22 +45 held | 4 | 28 | 53 | 121.0 | 12.1 | KD | - | crash 75 | +43 | - | KKK | - | 6.5 | 3.5 | 8/4 | super |
| bulk_smash_up |  | high | 22 | 4 | 28 | 53 | 55.0 | 5.5 | stun 26 | -6 | 16 | -16 | - | KKU | 16.5 | 1.5 | 9.5 | 8/4 | super |
| bulk_smash_up @full |  | high | 22 +45 held | 4 | 28 | 53 | 121.0 | 12.1 | KD | - | crash 75 | +43 | - | KKU | - | 1.5 | 9.5 | 8/4 | super |
| bulk_smash_down |  | low | 22 | 4 | 28 | 53 | 55.0 | 5.5 | stun 26 | -6 | 16 | -16 | - | KUK | 16.5 | 1.0 | -4.0 | 8/4 | super |
| bulk_smash_down @full |  | low | 22 +45 held | 4 | 28 | 53 | 121.0 | 12.1 | KD | - | crash 75 | +43 | - | KUK | - | 1.0 | -4.0 | 8/4 | super |
| bulk_smash_left |  | mid | 22 | 4 | 28 | 53 | 55.0 | 5.5 | stun 26 | -6 | 16 | -16 | - | KKK | 16.5 | 2.0 | 1.5 | 8/4 | super |
| bulk_smash_left @full |  | mid | 22 +45 held | 4 | 28 | 53 | 121.0 | 12.1 | KD | - | crash 75 | +43 | - | KKK | - | 2.0 | 1.5 | 8/4 | super |
| bulk_smash_right |  | mid | 22 | 4 | 28 | 53 | 55.0 | 5.5 | stun 26 | -6 | 16 | -16 | - | KKK | 16.5 | 2.0 | 1.5 | 8/4 | super |
| bulk_smash_right @full |  | mid | 22 +45 held | 4 | 28 | 53 | 121.0 | 12.1 | KD | - | crash 75 | +43 | - | KKK | - | 2.0 | 1.5 | 8/4 | super |
| bulk_charge_kick |  | mid | 25 | 4 | 31 | 59 | 70.0 | 7.0 | stagger 36 | +1 | 20 | -15 | - | KKK | 22.0 | 6.0 | 0.0 | 8/4 | super |
| bulk_charge_kick @full |  | mid | 25 +60 held | 4 | 31 | 59 | 140.0 | 14.0 | stagger 60 | +25 | crash 75 | +40 | - | KKK | - | 6.0 | 0.0 | 8/4 | super |
| bulk_jump_kick | jump_attack | mid | 8 | 8 | 12 | 27 | 50.0 | 5.0 | stun 24 | +4 | 12 | -8 | - | PPU | - | 3.0 | 0.0 | 4/4 |  |
| bulk_dive_kick | jump_heavy | mid | 10 | 12 | 14 | 35 | 65.0 | 6.5 | KD | - | 16 | -10 | - | KKU | 27.5 | 4.0 | 3.0 | 8/4 |  |
| bulk_duck_kick | duck_heavy | low | 8 | 4 | 21 | 32 | 55.0 | 5.5 | KD | - | 12 | -13 | -8 | KUO | 22.0 | 1.5 | 2.5 | 8/4 | super |
| bulk_getup_kick | getup_attack | low | 8 | 10 | 24 | 41 | 45.0 | 4.5 | KD | - | 12 | -22 | -8 | KUO | 16.5 | 4.0 | 3.0 | 8/4 |  |
| bulk_dash_punch | dash_attack | mid | 8 | 5 | 21 | 33 | 60.0 | 6.0 | KD | - | 14 | -12 | - | KKK | 22.0 | 8.0 | 3.5 | 8/4 |  |
| bulk_throw | throw | mid | 7 | 3 | 33 | 42 | 130.0 | 13.0 | KD | - | - | - | - | throw | - | 5.5 | 5.0 | 8/4 |  |
| bulk_counter | counter | mid | 5 | 4 | 26 | 34 | 70.0 | 7.0 | KD | - | 16 | -14 | -4 | OKK | 22.0 | 3.0 | 7.0 | 8/4 | super |
| bulk_ki_blast | ki_blast | mid | shot 10 | 0 | 19 | 28 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| bulk_ki_blast_shot | shot of bulk_ki_blast | mid | - | - | - | - | 25.0 | 2.5 | stun 16 | - | 8 | - | - | PPP | - | 2.0 | 0.0 | 3/3 | - |
| bulk_ki_blast_charged |  | mid | shot 13 | 0 | 24 | 36 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| bulk_ki_blast_charged @full |  | mid | shot 13 +30 held | 0 | 24 | 36 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| bulk_ki_blast_charged_shot | shot of bulk_ki_blast_charged | mid | - | - | - | - | 60.0 | 6.0 | KD | - | 14 | - | - | KKK | 22.0 | 6.0 | 4.0 | 8/4 | - |
| bulk_rush | super1 | mid | 10 | 6 | 35 | 50 | 40.0 | 4.0 | stun 40 | chain | 12 | -29 | - | KKK | 110.0 | 0.5 | 0.0 | 3/3 | auto bulk_rush_2 on hit |
| bulk_rush_2 |  | mid | 5 | 2 | 7 | 13 | 35.0 | 3.5 | stun 30 | chain | 12 | +3 | - | KKK | 16.5 | 0.5 | 0.0 | 3/3 | auto bulk_rush_3 on hit |
| bulk_rush_3 |  | mid | 5 | 2 | 7 | 13 | 35.0 | 3.5 | stun 30 | chain | 12 | +3 | - | KKK | 16.5 | 0.5 | 0.0 | 3/3 | auto bulk_rush_4 on hit |
| bulk_rush_4 |  | mid | 5 | 2 | 7 | 13 | 35.0 | 3.5 | stun 30 | chain | 12 | +3 | - | KKK | 16.5 | 0.5 | 0.0 | 3/3 | auto bulk_rush_finish on hit |
| bulk_rush_finish |  | mid | 8 | 3 | 33 | 43 | 120.0 | 12.0 | KD | - | 12 | -24 | - | KKK | 16.5 | 9.0 | 8.0 | 14/4 |  |
| bulk_beam | super2 | mid | shot 22 | 0 | 94 | 115 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| bulk_beam_shot | shot of bulk_beam | mid | - | - | - | - | 18.0 | 1.8 | stun 18 | - | 12 | - | - | KKK | 13.2 | 1.0 | 0.0 | 1/1 | - |
| bulk_ultimate | ultimate | mid | shot 36 | 0 | 142 | 177 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| bulk_ultimate_shot | shot of bulk_ultimate | mid | - | - | - | - | 22.0 | 2.2 | stun 18 | - | 14 | - | - | KKK | 27.5 | 1.0 | 0.0 | 1/1 | - |

### Sprite

| move | role | height | hit on | active | recovery | total | damage | dmg % | on hit | adv hit | guard stun | adv guard | adv push-off | guard m/h/l | ki guard %bar | push | lift | hitstop hit/guard | cancel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sprite_jab1 | light 1 | mid | 5 | 3 | 10 | 17 | 25.2 | 2.52 | stun 20 | +7 | 10 | -3 | - | PPP | - | 1.5 | 0.0 | 4/4 | 6-15 sprite_jab2 sprite_finisher_1 sprite_upper_hook sprite_sweep; super |
| sprite_jab2 | light 2 | mid | 5 | 3 | 10 | 17 | 25.2 | 2.52 | stun 20 | +7 | 10 | -3 | - | PPP | - | 1.5 | 0.0 | 4/4 | 6-15 sprite_hook sprite_finisher_2 sprite_upper_hook sprite_sweep; super |
| sprite_hook | light 3 | mid | 7 | 3 | 11 | 20 | 33.6 | 3.36 | stun 22 | +8 | 10 | -4 | - | PPP | - | 2.0 | 0.0 | 4/4 | 8-19 sprite_kick sprite_finisher_3 sprite_upper_hook sprite_sweep; super |
| sprite_kick | light 4 | mid | 8 | 4 | 14 | 25 | 37.8 | 3.78 | stun 26 | +8 | 10 | -8 | - | PPP | - | 2.0 | 0.0 | 4/4 | 9-22 sprite_ender sprite_finisher_4 sprite_upper_hook sprite_sweep; super |
| sprite_ender | light 5 | mid | 9 | 4 | 19 | 31 | 46.2 | 4.62 | stagger 34 | +11 | 14 | -9 | - | PPP | - | 4.5 | 0.0 | 8/4 | 10-27 sprite_finisher sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_1 |  | mid | 8 | 4 | 18 | 29 | 42.0 | 4.2 | stagger 30 | +8 | 18 | -4 | -2 | SKK | 29.8 | 1.0 | 0.0 | 8/4 | 11-25 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_1_charged |  | mid | 11 | 4 | 18 | 32 | 42.0 | 4.2 | stagger 30 | +8 | 18 | -4 | - | KKK | 29.8 | 7.5 | 5.0 | 8/4 | 13-27 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_1_charged @full |  | mid | 11 +45 held | 4 | 18 | 32 | 75.6 | 7.56 | KD | - | crash 75 | +53 | - | KKK | - | 7.5 | 5.0 | 8/4 | 13-27 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_2 |  | mid | 9 | 4 | 19 | 31 | 50.4 | 5.04 | stagger 28 | +5 | 18 | -5 | -2 | SKK | 29.8 | 5.5 | 0.0 | 8/4 | 11-25 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_2_charged |  | mid | 12 | 4 | 19 | 34 | 50.4 | 5.04 | stagger 28 | +5 | 18 | -5 | - | KKK | 29.8 | 7.5 | 5.0 | 8/4 | 14-28 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_2_charged @full |  | mid | 12 +45 held | 4 | 19 | 34 | 90.7 | 9.07 | KD | - | crash 75 | +52 | - | KKK | - | 7.5 | 5.0 | 8/4 | 14-28 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_3 |  | mid | 9 | 4 | 19 | 31 | 54.6 | 5.46 | stagger 36 | +13 | 18 | -5 | -2 | SKK | 29.8 | 1.5 | 0.0 | 8/4 | 11-25 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_3_charged |  | mid | 12 | 4 | 19 | 34 | 54.6 | 5.46 | stagger 36 | +13 | 18 | -5 | - | KKK | 29.8 | 7.5 | 5.0 | 8/4 | 14-28 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_3_charged @full |  | mid | 12 +45 held | 4 | 19 | 34 | 98.3 | 9.83 | KD | - | crash 75 | +52 | - | KKK | - | 7.5 | 5.0 | 8/4 | 14-28 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_4 |  | mid | 10 | 4 | 21 | 34 | 58.8 | 5.88 | stagger 42 | +17 | 18 | -7 | -2 | SKK | 29.8 | 1.0 | 0.0 | 8/4 | 11-25 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_4_charged |  | mid | 13 | 4 | 21 | 37 | 58.8 | 5.88 | stagger 42 | +17 | 18 | -7 | - | KKK | 29.8 | 7.5 | 5.0 | 8/4 | 15-29 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_4_charged @full |  | mid | 13 +45 held | 4 | 21 | 37 | 105.8 | 10.58 | KD | - | crash 75 | +50 | - | KKK | - | 7.5 | 5.0 | 8/4 | 15-29 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher | finisher | mid | 9 | 4 | 21 | 33 | 71.4 | 7.14 | KD | - | 18 | -7 | -2 | SKK | 29.8 | 6.5 | 6.0 | 8/4 | 11-25 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_charged |  | mid | 12 | 4 | 21 | 36 | 71.4 | 7.14 | KD | - | 18 | -7 | - | KKK | 29.8 | 7.5 | 5.0 | 8/4 | 14-28 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_finisher_charged @full |  | mid | 12 +45 held | 4 | 21 | 36 | 128.5 | 12.85 | KD | - | crash 75 | +50 | - | KKK | - | 7.5 | 5.0 | 8/4 | 14-28 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_upper_hook | heavy_high | high | 11 | 4 | 19 | 33 | 54.6 | 5.46 | KD | - | 18 | -5 | -2 | KOU | 25.5 | 0.6 | 8.5 | 8/4 | 12-30 sprite_jab1 (on contact); super |
| sprite_upper_hook_charged |  | high | 14 | 4 | 19 | 36 | 54.6 | 5.46 | KD | - | 18 | -5 | - | KKU | 25.5 | 0.6 | 10.5 | 8/4 | 15-30 sprite_jab1 (on contact); super |
| sprite_upper_hook_charged @full |  | high | 14 +45 held | 4 | 19 | 36 | 98.3 | 9.83 | KD | - | crash 75 | +52 | - | KKU | - | 0.6 | 10.5 | 8/4 | 15-30 sprite_jab1 (on contact); super |
| sprite_sweep | heavy_low | low | 11 | 4 | 21 | 35 | 50.4 | 5.04 | KD | - | 18 | -7 | -2 | KUO | 21.3 | 1.5 | 3.0 | 8/4 | 12-27 sprite_jab1 sprite_upper_hook (on contact); super |
| sprite_sweep_charged |  | low | 15 | 4 | 21 | 39 | 50.4 | 5.04 | KD | - | 18 | -7 | - | KUK | 21.3 | 3.0 | 4.0 | 8/4 | 16-31 sprite_jab1 sprite_upper_hook (on contact); super |
| sprite_sweep_charged @full |  | low | 15 +45 held | 4 | 21 | 39 | 90.7 | 9.07 | KD | - | crash 75 | +50 | - | KUK | - | 3.0 | 4.0 | 8/4 | 16-31 sprite_jab1 sprite_upper_hook (on contact); super |
| sprite_kick_mid | heavy | mid | 12 | 4 | 18 | 33 | 63.0 | 6.3 | stagger 36 | +14 | 20 | -2 | 0 | OKK | 38.3 | 2.5 | 0.0 | 8/4 | 14-28 sprite_jab1 sprite_upper_hook sprite_sweep (on contact); super |
| sprite_charge_punch |  | mid | 15 | 4 | 19 | 37 | 46.2 | 4.62 | stun 26 | +3 | 16 | -7 | - | KKK | 12.8 | 6.5 | 3.5 | 8/4 | super |
| sprite_charge_punch @full |  | mid | 15 +45 held | 4 | 19 | 37 | 101.6 | 10.16 | KD | - | crash 75 | +52 | - | KKK | - | 6.5 | 3.5 | 8/4 | super |
| sprite_smash_up |  | high | 15 | 4 | 19 | 37 | 46.2 | 4.62 | stun 26 | +3 | 16 | -7 | - | KKU | 12.8 | 1.5 | 9.5 | 8/4 | super |
| sprite_smash_up @full |  | high | 15 +45 held | 4 | 19 | 37 | 101.6 | 10.16 | KD | - | crash 75 | +52 | - | KKU | - | 1.5 | 9.5 | 8/4 | super |
| sprite_smash_down |  | low | 15 | 4 | 19 | 37 | 46.2 | 4.62 | stun 26 | +3 | 16 | -7 | - | KUK | 12.8 | 1.0 | -4.0 | 8/4 | super |
| sprite_smash_down @full |  | low | 15 +45 held | 4 | 19 | 37 | 101.6 | 10.16 | KD | - | crash 75 | +52 | - | KUK | - | 1.0 | -4.0 | 8/4 | super |
| sprite_smash_left |  | mid | 15 | 4 | 19 | 37 | 46.2 | 4.62 | stun 26 | +3 | 16 | -7 | - | KKK | 12.8 | 2.0 | 1.5 | 8/4 | super |
| sprite_smash_left @full |  | mid | 15 +45 held | 4 | 19 | 37 | 101.6 | 10.16 | KD | - | crash 75 | +52 | - | KKK | - | 2.0 | 1.5 | 8/4 | super |
| sprite_smash_right |  | mid | 15 | 4 | 19 | 37 | 46.2 | 4.62 | stun 26 | +3 | 16 | -7 | - | KKK | 12.8 | 2.0 | 1.5 | 8/4 | super |
| sprite_smash_right @full |  | mid | 15 +45 held | 4 | 19 | 37 | 101.6 | 10.16 | KD | - | crash 75 | +52 | - | KKK | - | 2.0 | 1.5 | 8/4 | super |
| sprite_charge_kick |  | mid | 17 | 4 | 21 | 41 | 58.8 | 5.88 | stagger 36 | +11 | 20 | -5 | - | KKK | 17.0 | 6.0 | 0.0 | 8/4 | super |
| sprite_charge_kick @full |  | mid | 17 +60 held | 4 | 21 | 41 | 117.6 | 11.76 | stagger 60 | +35 | crash 75 | +50 | - | KKK | - | 6.0 | 0.0 | 8/4 | super |
| sprite_jump_kick | jump_attack | mid | 6 | 8 | 8 | 21 | 42.0 | 4.2 | stun 24 | +8 | 12 | -4 | - | PPU | - | 3.0 | 0.0 | 4/4 |  |
| sprite_dive_kick | jump_heavy | mid | 7 | 12 | 10 | 28 | 54.6 | 5.46 | KD | - | 16 | -6 | - | KKU | 21.3 | 4.0 | 3.0 | 8/4 |  |
| sprite_duck_kick | duck_heavy | low | 6 | 4 | 14 | 23 | 46.2 | 4.62 | KD | - | 12 | -6 | -8 | KUO | 17.0 | 1.5 | 2.5 | 8/4 | super |
| sprite_getup_kick | getup_attack | low | 6 | 10 | 16 | 31 | 37.8 | 3.78 | KD | - | 12 | -14 | -8 | KUO | 12.8 | 4.0 | 3.0 | 8/4 |  |
| sprite_dash_punch | dash_attack | mid | 6 | 5 | 14 | 24 | 50.4 | 5.04 | KD | - | 14 | -5 | - | KKK | 17.0 | 6.0 | 3.0 | 8/4 |  |
| sprite_throw | throw | mid | 5 | 3 | 22 | 29 | 75.6 | 7.56 | KD | - | - | - | - | throw | - | 5.5 | 5.0 | 8/4 |  |
| sprite_counter | counter | mid | 3 | 4 | 18 | 24 | 58.8 | 5.88 | KD | - | 16 | -6 | -4 | OKK | 17.0 | 3.0 | 7.0 | 8/4 | super |
| sprite_ki_blast | ki_blast | mid | shot 7 | 0 | 13 | 19 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| sprite_ki_blast_shot | shot of sprite_ki_blast | mid | - | - | - | - | 21.0 | 2.1 | stun 16 | - | 8 | - | - | PPP | - | 2.0 | 0.0 | 3/3 | - |
| sprite_ki_blast_charged |  | mid | shot 9 | 0 | 16 | 24 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| sprite_ki_blast_charged @full |  | mid | shot 9 +30 held | 0 | 16 | 24 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| sprite_ki_blast_charged_shot | shot of sprite_ki_blast_charged | mid | - | - | - | - | 50.4 | 5.04 | KD | - | 14 | - | - | KKK | 17.0 | 6.0 | 4.0 | 8/4 | - |
| sprite_rush | super1 | mid | 7 | 6 | 24 | 36 | 33.6 | 3.36 | stun 40 | chain | 12 | -18 | - | KKK | 85.0 | 0.5 | 0.0 | 3/3 | auto sprite_rush_2 on hit |
| sprite_rush_2 |  | mid | 3 | 2 | 5 | 9 | 29.4 | 2.94 | stun 30 | chain | 12 | +5 | - | KKK | 12.8 | 0.5 | 0.0 | 3/3 | auto sprite_rush_3 on hit |
| sprite_rush_3 |  | mid | 3 | 2 | 5 | 9 | 29.4 | 2.94 | stun 30 | chain | 12 | +5 | - | KKK | 12.8 | 0.5 | 0.0 | 3/3 | auto sprite_rush_4 on hit |
| sprite_rush_4 |  | mid | 3 | 2 | 5 | 9 | 29.4 | 2.94 | stun 30 | chain | 12 | +5 | - | KKK | 12.8 | 0.5 | 0.0 | 3/3 | auto sprite_rush_finish on hit |
| sprite_rush_finish |  | mid | 6 | 3 | 22 | 30 | 100.8 | 10.08 | KD | - | 12 | -13 | - | KKK | 12.8 | 9.0 | 8.0 | 14/4 |  |
| sprite_beam | super2 | mid | shot 15 | 0 | 64 | 78 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| sprite_beam_shot | shot of sprite_beam | mid | - | - | - | - | 15.1 | 1.51 | stun 18 | - | 12 | - | - | KKK | 10.2 | 1.0 | 0.0 | 1/1 | - |
| sprite_ultimate | ultimate | mid | shot 25 | 0 | 96 | 120 | 0.0 | 0.0 | - | - | - | - | - | - | - | 1.5 | 0.0 | 4/4 |  |
| sprite_ultimate_shot | shot of sprite_ultimate | mid | - | - | - | - | 18.5 | 1.85 | stun 18 | - | 14 | - | - | KKK | 21.3 | 1.0 | 0.0 | 1/1 | - |

