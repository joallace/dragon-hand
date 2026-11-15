#!/usr/bin/env python3
"""Play a scripted two-pad fight in the BT3 PC port, headless, and print what
happened to each fighter's health, frame by frame.

Research tool for docs/bt3_sauce.md ("Measured in the port"). It uses the
port's own test switches (BT3_PAD_PLAY: recorded pad input, BT3_HASH: a state
line per vertical blank) with your own installed copy; no window is needed
and nothing here contains game data.

    python3 tools/reference/bt3_script.py <script file> [--shots <every>]

Script lines:  <pad 0|1> <first frame> <frames> <BUTTON[+BUTTON...]>   (# comment)
Frames are pad frames: 60 per second in the menus, one per 30 Hz game frame in
a fight. The built-in prelude walks the menus from boot to Duel > 1P VS 2P >
Single Battle with Goku (Early) on both sides; the fight has started by pad
frame ~4600. Keep fight inputs relative to each other: the fight's start
moves by a few frames between runs, so let player 1 walk in first (hold UP
from 4300 to ~4690) and only then press.

Buttons (PS2 names; defaults: SQUARE rush, TRIANGLE ki blast, CIRCLE guard,
CROSS dash, UP = toward the opponent).

Environment: BT3_INSTALL (default ~/Downloads/Tenkaichi3Decomp), BT3_WORK
(scratch folder, default builds/research/bt3run next to the repo root).
"""
import math
import os
import re
import shutil
import struct
import subprocess
import sys

INSTALL = os.environ.get(
    "BT3_INSTALL", os.path.expanduser("~/Downloads/Tenkaichi3Decomp"))
WORK = os.environ.get("BT3_WORK", os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..",
    "builds", "research", "bt3run"))

B0 = dict(SELECT=1, L3=2, R3=4, START=8, UP=0x10, RIGHT=0x20, DOWN=0x40,
          LEFT=0x80)
B1 = dict(L2=1, R2=2, L1=4, R1=8, TRIANGLE=0x10, CIRCLE=0x20, CROSS=0x40,
          SQUARE=0x80)

# Boot (empty save folder) -> title -> New Game -> Duel -> 1P VS 2P ->
# Single Battle -> both pick Goku (Early), defaults for everything else.
PRELUDE = """
0 2500 4 START
0 2620 4 CROSS
0 2800 4 DOWN
0 2820 4 DOWN
0 2840 4 DOWN
0 2870 4 CROSS
0 3000 4 DOWN
0 3030 4 CROSS
0 3070 4 CROSS
1 3680 4 LEFT
0 3720 4 CROSS
1 3720 4 CROSS
""" + "".join("%d %d 4 CROSS\n" % (pad, frame)
              for frame in range(3770, 4131, 60) for pad in (0, 1))

LAST_FRAME = 4800
LINKS = ("gamedata fonts tbo lib textures translations songs stages "
         "Tenkaichi3Decomp.dat Tenkaichi3Decomp.mem bt3_pipelines.txt").split()


def build_pad(text, total):
    frames = [[[0, 0], [0, 0]] for _ in range(total)]
    for line in text.splitlines():
        parts = line.split("#")[0].split()
        if not parts:
            continue
        pad, start, count = int(parts[0]), int(parts[1]), int(parts[2])
        for name in parts[3].split("+"):
            table, byte = (B0, 0) if name in B0 else (B1, 1)
            for frame in range(start, min(start + count, total)):
                frames[frame][pad][byte] |= table[name]
    out = bytearray()
    for frame in frames:        # two pad reads (pad 0, pad 1) per frame
        for pad in frame:
            out += bytes([0xFF ^ pad[0], 0xFF ^ pad[1],
                          0x80, 0x80, 0x80, 0x80]) + bytes(12)
    return bytes(out)


def run(script_text, shots=0, seconds=25):
    os.makedirs(WORK, exist_ok=True)
    for name in LINKS:
        link = os.path.join(WORK, name)
        if not os.path.lexists(link):
            os.symlink(os.path.join(INSTALL, name), link)
    saves = os.path.join(WORK, "saves_run")
    shutil.rmtree(saves, ignore_errors=True)
    os.makedirs(saves)
    shot_dir = os.path.join(WORK, "port", "build", "shots")
    shutil.rmtree(shot_dir, ignore_errors=True)
    if shots:
        os.makedirs(shot_dir)   # the port only writes pictures if it exists
    pad_path = os.path.join(WORK, "run.pad")
    with open(pad_path, "wb") as f:
        f.write(build_pad(PRELUDE + script_text, LAST_FRAME))
    log = os.path.join(WORK, "state.log")
    if os.path.exists(log):
        os.remove(log)
    env = dict(os.environ, BT3_SETTINGS="", BT3_SAVES=saves,
               BT3_PAD_PLAY=pad_path, BT3_NOMOVIE="1", BT3_UNCAPPED="1",
               BT3_HASH=log)
    if shots:
        env["BT3_SHOT"] = str(shots)
    try:    # the game does not stop by itself once the recording ends
        subprocess.run([os.path.join(INSTALL, "Tenkaichi3Decomp")], cwd=WORK,
                       env=env, timeout=seconds, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        pass
    return log


def read_states(log):
    pattern = re.compile(
        r"^(\d+) .* hp (\d+) (\d+) pos (\w+) (\w+) (\w+)  (\w+) (\w+) (\w+)"
        r" clock (-?\d+)(?:.*pad (\d+))?")
    as_float = lambda h: struct.unpack(">f", bytes.fromhex(h))[0]
    rows = []
    with open(log) as f:
        for line in f:
            m = pattern.search(line)
            if m:
                pos = [as_float(m[k]) for k in range(4, 10)]
                rows.append({
                    "vblank": int(m[1]), "hp": (int(m[2]), int(m[3])),
                    "dist": math.dist(pos[:3], pos[3:]),
                    "tick": int(m[10]),
                    "pad_frame": int(m[11]) // 36 if m[11] else -1})
    return rows


def report(rows):
    if not rows:
        print("no fight reached (check the install path and the prelude)")
        return
    prev = rows[0]
    print("fight rows %d, start hp %s" % (len(rows), prev["hp"]))
    for row in rows:
        if row["hp"] != prev["hp"]:
            print("pad frame %d (tick %d): hp %s  P1 -%d  P2 -%d  dist %.1f" % (
                row["pad_frame"], row["tick"], row["hp"],
                prev["hp"][0] - row["hp"][0], prev["hp"][1] - row["hp"][1],
                row["dist"]))
            prev = row
    print("end: pad frame %d hp %s dist %.1f" % (
        rows[-1]["pad_frame"], rows[-1]["hp"], rows[-1]["dist"]))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    shot_every = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[2] == "--shots" else 0
    with open(sys.argv[1]) as f:
        report(read_states(run(f.read(), shot_every)))
