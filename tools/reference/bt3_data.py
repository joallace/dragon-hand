#!/usr/bin/env python3
"""Read Budokai Tenkaichi 3 tuning tables out of YOUR OWN unpacked disc data.

Research tool for docs/bt3_sauce.md. It reads the files the BT3 PC port
(https://github.com/z3xox/Tenkaichi3Decomp) unpacks from the user's disc into
`<install>/gamedata/pzs3us1/`. It contains no game data and no decomp code; the
layouts below are format facts documented in that project's headers
(`include/battle/btl_tech_a.h`, `btl_tech_b.h`, `bobj_a.h`). Never commit its
output tables wholesale: quote numbers in our docs, in our own words.

    python3 tools/reference/bt3_data.py atk   <chara> [hex ids]   attack records
    python3 tools/reference/bt3_data.py anim  <chara> <hex ids>   length + events
    python3 tools/reference/bt3_data.py param <chara>[,<chara>..] parameter block
    python3 tools/reference/bt3_data.py roster                    spread over all

`BT3_GAMEDATA` overrides the data folder (default: the port in ~/Downloads).
All frame numbers printed are the game's 30 Hz frames (x2 for our 60 Hz).
"""
import os
import statistics
import struct
import sys

DATA = os.environ.get(
    "BT3_GAMEDATA",
    os.path.expanduser("~/Downloads/Tenkaichi3Decomp/gamedata/pzs3us1"))

# Global file ids (docs/systems/files_and_assets.md): archive index = id - 1.
MODEL_ID = 0x590   # + chara * 10 + costume: model pack (holds the tables)
ANIM_ID = 0x598    # + chara * 10: animation pack

# Entries of the model pack (BtlObj_BindTables).
E_PARAM, E_ATTACK, E_KIBLAST, E_MOVE = 0x12, 0x13, 0x14, 0x15

ATK_COUNT = 0xA3
ATK_FMT = "<I7H3B2b4B7b4b4b2b3B"   # 0x30 bytes
ATK_NAMES = (
    "flags dmg gdmg gki kigain thC thE momentum pushH pushG lunge angA angB "
    "shP shT shPg shTg react rB rD rE rC rSub rF rG fx snd voice prio "
    "gUp gDown gMid gE gSel armIg").split()


def pack(file_id):
    path = os.path.join(DATA, "%05d.bin" % (file_id - 1))
    with open(path, "rb") as f:
        buf = f.read()
    count = struct.unpack_from("<I", buf, 0)[0]
    offs = struct.unpack_from("<%dI" % (count + 1), buf, 4)
    return buf, offs


def entry(pk, n):
    """Entry n of a pack's offset table (1-based), None when empty."""
    buf, offs = pk
    a, e = offs[n - 1], offs[n]
    return buf[a & ~3:e] if a != e else None


def bpe_expand(src):
    """Byte-pair expansion (the classic public-domain 'expand' routine)."""
    raw, packed = struct.unpack_from("<II", src, 0)
    p, end, out = 8, 8 + packed, bytearray()
    while p < end and len(out) < raw:
        left, right, c = list(range(256)), [0] * 256, 0
        while True:
            count = src[p]; p += 1
            if count > 127:
                c += count - 127
                count = 0
            if c == 256:
                break
            for _ in range(count + 1):
                left[c] = src[p]; p += 1
                if c != left[c]:
                    right[c] = src[p]; p += 1
                c += 1
            if c == 256:
                break
        size = (src[p] << 8) | src[p + 1]; p += 2
        stack = []
        while True:
            if stack:
                ch = stack.pop()
            elif size == 0:
                break
            else:
                size -= 1
                ch = src[p]; p += 1
            if ch == left[ch]:
                out.append(ch)
            else:
                stack.append(right[ch])
                stack.append(left[ch])
    return bytes(out[:raw])


def attack_records(chara, costume=0):
    table = entry(pack(MODEL_ID + chara * 10 + costume), E_ATTACK)
    return [dict(zip(ATK_NAMES, struct.unpack_from(ATK_FMT, table, i * 0x30)))
            for i in range(ATK_COUNT)]


def animation(pk, anim_id):
    """(length, [(frame, attribute bits, argument)]) or None."""
    data = entry(pk, anim_id + 1)
    if data is None or len(data) < 16:
        return None
    data = bpe_expand(data)
    if len(data) < 0x94:
        return None
    events = []
    for k in range(data[1]):
        lo, hi, frame, _shape, arg = struct.unpack_from(
            "<IIHHI", data, 0x94 + k * 0x10)
        events.append((frame, (hi << 32) | lo, arg))
    return struct.unpack_from("<H", data, 2)[0], sorted(events)


def params(chara):
    pk = pack(MODEL_ID + chara * 10)
    p, mv = entry(pk, E_PARAM), entry(pk, E_MOVE)
    f = lambda d, o: struct.unpack_from("<f", d, o)[0]
    i = lambda d, o: struct.unpack_from("<i", d, o)[0]
    atk = attack_records(chara)
    speed = struct.unpack_from("<20f", mv, 0)
    return {
        "chara": chara,
        "ki_charge_s": i(p, 0x30), "ki_regen_s": i(p, 0x38),
        "ki_regen_limit": i(p, 0x28), "ki_recover_s": i(p, 0x3C),
        "blast_gain_s": i(p, 0x44), "air_recover_cost": i(p, 0x48),
        "maxpower_charge_s": round(f(p, 0x50), 2),
        "maxpower_time_s": round(f(p, 0x54), 2),
        "hit_react_scale": round(f(p, 0x60), 2),
        "smash_charge_rate": (round(f(p, 0x74), 2), round(f(p, 0x78), 2)),
        "damage_taken": round(f(p, 0x7C), 2),
        "walk": speed[0], "close_move": speed[2], "dash": speed[4],
        "homing_dash": speed[6],
        "rush_dmg": [atk[k]["dmg"] for k in range(1, 6)],
        "smash_full_dmg": atk[0x21]["dmg"], "throw_dmg": atk[0x55]["dmg"],
    }


def cmd_atk(args):
    recs = attack_records(int(args[0]))
    ids = ([int(x, 16) for x in args[1].split(",")] if len(args) > 1
           else range(ATK_COUNT))
    print("id  " + " ".join("%6s" % n[:6] for n in ATK_NAMES))
    for k in ids:
        r = recs[k]
        if any(r.values()):
            print("%02X  " % k + " ".join(
                "%6s" % (("%X" % r[n]) if n == "flags" else r[n])
                for n in ATK_NAMES))


def cmd_anim(args):
    pk = pack(ANIM_ID + int(args[0]) * 10)
    for anim_id in (int(x, 16) for x in args[1].split(",")):
        a = animation(pk, anim_id)
        if a is None:
            print("%03X -" % anim_id)
            continue
        print("%03X len %3d  %s" % (anim_id, a[0], " ".join(
            "%d:%X" % (fr, attr) for fr, attr, _ in a[1])))


def cmd_param(args):
    for chara in (int(x) for x in args[0].split(",")):
        print(params(chara))


def cmd_roster(_args):
    rows, jabs = [], []
    for chara in range(0, 200):
        try:
            rows.append(params(chara))
            a = animation(pack(ANIM_ID + chara * 10), 0x37)
            if a:
                opens = [fr for fr, attr, _ in a[1] if attr & 1]
                jabs.append((a[0], opens[0] if opens else -1))
        except (OSError, struct.error, IndexError, TypeError):
            continue
    print("characters read:", len(rows))

    def spread(name, values):
        values = sorted(values)
        print("%-22s min %-8g median %-8g max %-8g" % (
            name, values[0], statistics.median(values), values[-1]))
    for key in ("ki_charge_s", "ki_regen_s", "ki_regen_limit", "damage_taken",
                "hit_react_scale", "walk", "close_move", "dash",
                "smash_full_dmg", "throw_dmg"):
        spread(key, [r[key] for r in rows])
    spread("jab dmg", [r["rush_dmg"][0] for r in rows])
    spread("smash charge (cold)", [r["smash_charge_rate"][0] for r in rows])
    spread("smash charge (hot)", [r["smash_charge_rate"][1] for r in rows])
    spread("jab length @30", [j[0] for j in jabs])
    spread("jab first hit @30", [j[1] for j in jabs if j[1] >= 0])
    no_z = sum(1 for r in rows
               if not attack_records(r["chara"])[2]["flags"] & 1)
    print("rush step 2 NOT evadable (flag bit 1 clear): %d / %d" % (
        no_z, len(rows)))
    z = sum(1 for r in rows if attack_records(r["chara"])[0x1C]["flags"] & 1)
    print("medium smash evadable (flag bit 1 set): %d / %d" % (z, len(rows)))
    g = sum(1 for r in rows if attack_records(r["chara"])[0]["flags"] & 0x10)
    print("first rush hit timed-guardable (flag 0x10): %d / %d" % (
        g, len(rows)))


if __name__ == "__main__":
    commands = {"atk": cmd_atk, "anim": cmd_anim, "param": cmd_param,
                "roster": cmd_roster}
    if len(sys.argv) < 2 or sys.argv[1] not in commands:
        sys.exit(__doc__)
    commands[sys.argv[1]](sys.argv[2:])
