#!/usr/bin/env python3
"""Play a scripted pad from a God Hand: Rearmed save state, headless, and
print what happened frame by frame: Gene's motions (with the motion frame
each one was cut at), health changes of Gene and the enemies, and any
frame where the hitstop counter runs.

Research tool for docs/god_hand_reference.md ("Measured in Rearmed"). It
uses the port's own test mode (`--headless --test <script>`) with your own
disc and a save state you made with F5 in a fight; nothing here contains
game data.

    python3 tools/reference/ghr_script.py <script file> [--trace <first>-<last>]
        [--state <file.state>] [--keep <dir>]

Script lines:  <first sample> <samples> <BUTTON[+BUTTON...]>   (# comment)
One sample per 30 Hz game frame (two 60 Hz frames; the test runs at 60 FPS
when the save state was made with Fps60=1). Buttons: the PS2 names (SQUARE,
TRIANGLE, CIRCLE, CROSS, L1, R1, L2, R2, START, SELECT, UP, DOWN, LEFT,
RIGHT, L3, R3) and full stick pushes (LUP, LDOWN, LLEFT, LRIGHT, RUP...).
Two presses of the same button need a released sample between them.

What the port's test mode takes (read from its messages, 2026-11-25,
v0.6.9.6): a script of `key=value` lines, `state=<.state>`,
`frames=<30 Hz frames>`, `input=<pad file>`; the pad file holds one line
of 64 hex digits per sample (the 32-byte PS2 pad buffer: status, 0x73,
two active-low button bytes, rx, ry, lx, ly, pressures). It writes
`<input>_play.csv` (one row per 60 Hz frame: pad, `hitstop`, Gene's
`pl_*` fields incl. `pl_motion` / `pl_mframe` / `pl_hp`, and `emN_*` per
enemy) next to the pad file. A run quits by itself after `frames`.

Environment: GHR_APP (default: the newest GHR-*-Linux-x64.AppImage in
~/Downloads/God Hand Rearmed), GHR_STATE (default
~/.local/share/GodHandRearmed/states/quick.state).
"""
import csv
import glob
import os
import subprocess
import sys
import tempfile

B2 = dict(SELECT=1, L3=2, R3=4, START=8, UP=0x10, RIGHT=0x20, DOWN=0x40, LEFT=0x80)
B3 = dict(L2=1, R2=2, L1=4, R1=8, TRIANGLE=0x10, CIRCLE=0x20, CROSS=0x40, SQUARE=0x80)
STICK = dict(RRIGHT=(4, 0xFF), RLEFT=(4, 0), RDOWN=(5, 0xFF), RUP=(5, 0),
             LRIGHT=(6, 0xFF), LLEFT=(6, 0), LDOWN=(7, 0xFF), LUP=(7, 0))
TAIL = 60   # samples played after the last input


def default_app():
    apps = sorted(glob.glob(os.path.expanduser(
        "~/Downloads/God Hand Rearmed/GHR-*-Linux-x64.AppImage")))
    return os.environ.get("GHR_APP", apps[-1] if apps else "")


def parse_script(text):
    events = []
    for line in text.splitlines():
        parts = line.split("#")[0].split()
        if parts:
            events.append((int(parts[0]), int(parts[1]), parts[2].split("+")))
    return events


def build_pad(events):
    total = max([first + count for first, count, _ in events] + [0]) + TAIL
    frames = [[0, 0x73, 0xFF, 0xFF, 0x80, 0x80, 0x80, 0x80] + [0] * 24
              for _ in range(total)]
    for first, count, names in events:
        for f in range(first, first + count):
            for name in names:
                if name in B2:
                    frames[f][2] &= ~B2[name] & 0xFF
                elif name in B3:
                    frames[f][3] &= ~B3[name] & 0xFF
                elif name in STICK:
                    k, v = STICK[name]
                    frames[f][k] = v
                else:
                    sys.exit("unknown button %s" % name)
    return "".join("".join("%02x" % b for b in fr) + "\n" for fr in frames), total


def run(script_text, state, work):
    pad_text, samples = build_pad(parse_script(script_text))
    pad = os.path.join(work, "pad")
    with open(pad, "w") as f:
        f.write(pad_text)
    test = os.path.join(work, "test.txt")
    with open(test, "w") as f:
        f.write("state=%s\nframes=%d\ninput=%s\n" % (state, samples, pad))
    app = default_app()
    if not app:
        sys.exit("no Rearmed AppImage found (set GHR_APP)")
    limit = 30 + samples // 10
    subprocess.run([app, "--headless", "--time-limit", str(limit), "--test", test],
                   cwd=work, timeout=limit + 60, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL)
    out = pad + "_play.csv"
    if not os.path.exists(out):
        sys.exit("no log written (see the test: lines in "
                 "~/.local/share/GodHandRearmed/logs/kamite.log)")
    with open(out) as f:
        return list(csv.DictReader(f))


def enemies(row):
    return [k[:-3] for k in row if k.startswith("em") and k.endswith("_hp")]


def report(rows, trace=None):
    if not rows:
        print("no rows")
        return
    ems = enemies(rows[0])
    print("frames %d, Gene hp %s, enemies %s" % (
        len(rows), rows[0]["pl_hp"], " ".join("%s=%s" % (e, rows[0][e + "_hp"]) for e in ems)))
    prev = rows[0]
    for row in rows[1:]:
        notes = []
        if row["pl_motion"] != prev["pl_motion"]:
            notes.append("Gene motion %s (cut %s at mf %s)" % (
                row["pl_motion"], prev["pl_motion"], prev["pl_mframe"]))
        if row["pl_hp"] != prev["pl_hp"]:
            notes.append("Gene hp %s -> %s" % (prev["pl_hp"], row["pl_hp"]))
        for e in ems:
            if row[e + "_hp"] != prev[e + "_hp"]:
                notes.append("%s hp %s -> %s" % (e, prev[e + "_hp"], row[e + "_hp"]))
        if row["hitstop"] != "0":
            notes.append("hitstop %s" % row["hitstop"])
        frame = int(row["frame"])
        if notes or (trace and trace[0] <= frame <= trace[1]):
            print("frame %4d btn %s  mf %-7s %s" % (
                frame, row["buttons"], row["pl_mframe"], "; ".join(notes)))
        prev = row


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    trace, keep = None, None
    state = os.environ.get("GHR_STATE", os.path.expanduser(
        "~/.local/share/GodHandRearmed/states/quick.state"))
    while len(args) > 1:
        flag = args.pop(1)
        if flag == "--trace":
            first, last = args.pop(1).split("-")
            trace = (int(first), int(last))
        elif flag == "--state":
            state = args.pop(1)
        elif flag == "--keep":
            keep = args.pop(1)
        else:
            sys.exit("unknown option %s\n%s" % (flag, __doc__))
    with open(args[0]) as f:
        text = f.read()
    if keep:
        os.makedirs(keep, exist_ok=True)
        report(run(text, state, keep), trace)
    else:
        with tempfile.TemporaryDirectory() as work:
            report(run(text, state, work), trace)
