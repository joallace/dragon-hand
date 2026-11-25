#!/usr/bin/env python3
"""Play a scripted two-pad fight in the BT3 PC port, headless, and print what
happened to each fighter's health, frame by frame.

Research tool for docs/bt3_sauce.md ("Measured in the port"). It uses the
port's own test switches (BT3_PAD_PLAY: recorded pad input, BT3_HASH: a state
line per vertical blank) with your own installed copy; no window is needed
and nothing here contains game data.

    python3 tools/reference/bt3_script.py <script file> [--shots <every>]
        [--probe] [--trace <first>-<last>]

--probe runs the port under gdb (needs gdb) and adds, per frame, what the
hash line lacks: ki and blast stock (BtlSide_GetKi / GetBlast), the current
action id, the stun timer and the two smash charge-rate values of each side;
lines are printed when health, ki or the action change or stun is
dealt. --trace prints every frame in a pad-frame range.

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
import signal
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


def script_end(text):
    """Pad frames the recording needs: LAST_FRAME, or past the last input."""
    end = LAST_FRAME
    for line in text.splitlines():
        parts = line.split("#")[0].split()
        if parts:
            end = max(end, int(parts[1]) + int(parts[2]) + 100)
    return end


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


# --probe: run the port under gdb and print, once per logged fight frame,
# what the hash line lacks. The port keeps its symbols; the layout below is
# read from its own accessors. The fighter list (*0x20719a54) holds a count
# and then records of 0x1600 bytes: +0x8 side, +0x948 current action
# (BtlAct_GetCurrent), +0xfe0 stun timer, +0xd78 / +0xdec the two values
# BtlCharApi_GetChargeRate takes the larger of; the active gauge
# (BtlMember_GetActiveGauge) is at +0x9e4 + 0xa4 * (+0x994): +0x0 health,
# +0xc ki, +0x14 blast stock. Only memory reads per frame (no calls into the
# game), and the per-frame breakpoint is armed at BtlScene_Init: stopping on
# every menu vblank is far too slow.
PROBE_GDB = """set debuginfod enabled off
set pagination off
set confirm off
handle SIGPIPE SIGUSR1 SIGUSR2 SIG32 SIG33 SIG34 nostop noprint pass
break Port_StateLog
disable 1
commands 1
silent
set $L = *(unsigned*)0x20719a54
if $rsi != 0 && $L != 0 && *(int*)(long)$L >= 2
set $c0 = *(unsigned*)(long)($L + 4)
set $c1 = $c0 + 0x1600
set $g0 = $c0 + 0x9e4 + 0xa4 * *(int*)(long)($c0 + 0x994)
set $g1 = $c1 + 0x9e4 + 0xa4 * *(int*)(long)($c1 + 0x994)
printf "PROBE %d side %d %d", $rdi, *(int*)(long)($c0 + 8), *(int*)(long)($c1 + 8)
printf " ki %d %d", *(int*)(long)($g0 + 0xc), *(int*)(long)($g1 + 0xc)
printf " blast %d %d", *(int*)(long)($g0 + 0x14), *(int*)(long)($g1 + 0x14)
printf " act %d %d", *(int*)(long)($c0 + 0x948), *(int*)(long)($c1 + 0x948)
printf " stun %d %d", *(int*)(long)($c0 + 0xfe0), *(int*)(long)($c1 + 0xfe0)
printf " chargeA %.3f %.3f", *(float*)(long)($c0 + 0xd78), *(float*)(long)($c1 + 0xd78)
printf " chargeB %.3f %.3f\\n", *(float*)(long)($c0 + 0xdec), *(float*)(long)($c1 + 0xdec)
end
continue
end
break BtlScene_Init
commands 2
silent
enable 1
continue
end
run
"""


def run(script_text, shots=0, seconds=None, probe=False):
    if seconds is None:     # ~5000 pad frames take 25 s uncapped
        seconds = 25 * script_end(script_text) // LAST_FRAME
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
        f.write(build_pad(PRELUDE + script_text, script_end(script_text)))
    log = os.path.join(WORK, "state.log")
    if os.path.exists(log):
        os.remove(log)
    env = dict(os.environ, BT3_SETTINGS="", BT3_SAVES=saves,
               BT3_PAD_PLAY=pad_path, BT3_NOMOVIE="1", BT3_UNCAPPED="1",
               BT3_HASH=log)
    if shots:
        env["BT3_SHOT"] = str(shots)
    cmd = [os.path.join(INSTALL, "Tenkaichi3Decomp")]
    out = subprocess.DEVNULL
    probe_log = os.path.join(WORK, "probe.log")
    if probe:
        gdb_script = os.path.join(WORK, "probe.gdb")
        with open(gdb_script, "w") as f:
            f.write(PROBE_GDB)
        cmd = ["gdb", "-batch", "-x", gdb_script, "--args"] + cmd
        out = open(probe_log, "w")
        seconds *= 4    # a breakpoint per frame slows the run down
    # The game does not stop by itself once the recording ends: kill its
    # process group (with --probe, gdb's; gdb kills the game it started when
    # it dies).
    proc = subprocess.Popen(cmd, cwd=WORK, env=env, stdout=out,
                            stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        proc.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.wait()
    if probe:
        out.close()
    return log, (probe_log if probe else None)


def read_probe(probe_log):
    """vblank -> {field: (P1, P2)} from the --probe gdb output."""
    probes = {}
    if not probe_log:
        return probes
    with open(probe_log) as f:
        for line in f:
            if not line.startswith("PROBE "):
                continue
            parts = line.split()
            fields = {}
            try:    # the run ends in a kill: the last line may be cut off
                for k in range(2, len(parts) - 2, 3):
                    cast = float if parts[k].startswith("charge") else int
                    fields[parts[k]] = (cast(parts[k + 1]), cast(parts[k + 2]))
                probes[int(parts[1])] = fields
            except (ValueError, IndexError):
                continue
    return probes


def read_states(log, probe_log=None):
    probes = read_probe(probe_log)
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
                    "pad_frame": int(m[11]) // 36 if m[11] else -1,
                    "probe": probes.get(int(m[1]))})
    return rows


def _probe_text(probe):
    if not probe:
        return ""
    return "  " + " ".join(
        "%s %s/%s" % (name, *(("%.2f" % v) if isinstance(v, float) else v
                              for v in pair))
        for name, pair in probe.items())


def report(rows, trace=None, end=LAST_FRAME):
    """Prints health changes; with probe data also ki / blast / action
    changes and new stun. trace=(first, last) pad frames prints every row."""
    if not rows:
        print("no fight reached (check the install path and the prelude)")
        return
    prev = rows[0]
    print("fight rows %d, start hp %s%s" % (len(rows), prev["hp"],
                                            _probe_text(prev["probe"])))
    last_probe = prev["probe"] or {}
    last = prev
    for row in rows:
        probe = row["probe"] or {}
        if row["pad_frame"] >= end:
            break       # the recording is over; the fighters just idle
        last = row
        changed = [k for k in ("ki", "act")
                   if k in probe and probe[k] != last_probe.get(k)]
        if "stun" in probe and any(
                probe["stun"][s] > last_probe.get("stun", (0, 0))[s]
                for s in (0, 1)):
            changed.append("stun")
        traced = trace and trace[0] <= row["pad_frame"] <= trace[1]
        if row["hp"] != prev["hp"] or changed or traced:
            print("pad frame %d (tick %d): hp %s  P1 -%d  P2 -%d  dist %.1f%s" % (
                row["pad_frame"], row["tick"], row["hp"],
                prev["hp"][0] - row["hp"][0], prev["hp"][1] - row["hp"][1],
                row["dist"], _probe_text(probe)))
            prev = row
        if probe:
            last_probe = probe
    print("end: pad frame %d hp %s dist %.1f" % (
        last["pad_frame"], last["hp"], last["dist"]))


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    shot_every, probe, trace = 0, False, None
    while len(args) > 1:
        flag = args.pop(1)
        if flag == "--shots":
            shot_every = int(args.pop(1))
        elif flag == "--probe":
            probe = True
        elif flag == "--trace":
            first, last = args.pop(1).split("-")
            trace = (int(first), int(last))
        else:
            sys.exit("unknown option %s\n%s" % (flag, __doc__))
    with open(args[0]) as f:
        text = f.read()
    report(read_states(*run(text, shot_every, probe=probe)), trace,
           script_end(text))
