#!/usr/bin/env python3
"""Disassemble one God Hand function from your own retail boot ELF, with the
game's function names, to re-check docs/god_hand_reference.md.

Research tool (third pass). Reads two files of the God Hand: Rearmed install
(nothing here contains game data):

- game_data/SLUS_215.03: the boot ELF the port extracts from your disc;
- GHR.exe: the port's exe, which carries a table of (start, end, name) for
  ~4300 game functions; used for the names and each function's end.

    python3 -I tools/reference/gh_disasm.py <address | name> [<end address>]
    python3 -I tools/reference/gh_disasm.py --find <substring>
    python3 -I tools/reference/gh_disasm.py --word <address> [...]

Examples:  0x123938 (the action chooser), cEmManage_countEmNearerPlayer,
--word 0x3BD4A0 (God Hand drain per game frame).

Needs llvm-objdump (MIPS target). R5900-only quadword loads/stores, which
llvm prints as "ext" / <unknown>, are shown as lq / sq. Each `lui` and
`lui+ori` pair is annotated with the value read as a float, and each jal with
the target's name.

Environment: GH_INSTALL (default ~/Downloads/God Hand Rearmed).
"""
import os
import re
import struct
import subprocess
import sys

INSTALL = os.environ.get(
    "GH_INSTALL", os.path.expanduser("~/Downloads/God Hand Rearmed"))
ELF = os.path.join(INSTALL, "game_data", "SLUS_215.03")
EXE = os.path.join(INSTALL, "GHR.exe")


def load_elf(path):
    data = open(path, "rb").read()
    phoff = struct.unpack_from("<I", data, 0x1C)[0]
    phnum = struct.unpack_from("<H", data, 0x2C)[0]
    segs = []
    for i in range(phnum):
        kind, off, vaddr, _, filesz, memsz, _, _ = struct.unpack_from(
            "<8I", data, phoff + i * 32)
        if kind == 1:
            segs.append((vaddr, off, filesz, memsz))
    return data, segs


def read_word(elf, addr):
    data, segs = elf
    for vaddr, off, filesz, _ in segs:
        if vaddr <= addr < vaddr + filesz - 3:
            return struct.unpack_from("<I", data, off + addr - vaddr)[0]
    return None


def load_names(path):
    """The port's function table: 16-byte rows (u32 start, u32 end, u64 name
    pointer) in .rdata. Found by looking for a row whose name is a known
    function, then walking both ways while rows stay valid."""
    data = open(path, "rb").read()
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    nsec = struct.unpack_from("<H", data, pe + 6)[0]
    optsz = struct.unpack_from("<H", data, pe + 20)[0]
    base = struct.unpack_from("<Q", data, pe + 24 + 24)[0]
    secs = []
    o = pe + 24 + optsz
    for _ in range(nsec):  # section header: VirtualAddress, SizeOfRawData, PointerToRawData
        rva = struct.unpack_from("<I", data, o + 12)[0]
        rawsz, rawptr = struct.unpack_from("<II", data, o + 16)
        secs.append((rva, rawptr, rawsz))
        o += 40

    def to_off(va):
        r = va - base
        for rva, rawptr, rawsz in secs:
            if rva <= r < rva + rawsz:
                return r - rva + rawptr
        return None

    def name_at(va):
        off = to_off(va)
        if off is None:
            return None
        end = data.find(b"\0", off, off + 200)
        if end < 0:
            return None
        try:
            text = data[off:end].decode("ascii")
        except UnicodeDecodeError:
            return None
        return text if text.isprintable() and text else None

    def row(off):
        start, end, ptr = struct.unpack_from("<IIQ", data, off)
        if 0x100000 <= start < 0x2000000 and start <= end:
            name = name_at(ptr)
            if name:
                return start, end, name
        return None

    anchor = data.find(b"cEmManage_countEmNearerPlayer\0")
    if anchor < 0:
        sys.exit("function table not found in " + path)
    anchor_va = None
    for rva, rawptr, rawsz in secs:
        if rawptr <= anchor < rawptr + rawsz:
            anchor_va = base + rva + anchor - rawptr
    ref = data.find(struct.pack("<Q", anchor_va))
    first = ref - 8
    while row(first - 16):
        first -= 16
    last = ref - 8
    while row(last):
        last += 16
    rows = [row(o) for o in range(first, last, 16)]
    return sorted(rows)


def describe(elf, names, start, end):
    by_addr = {s: n for s, _, n in names}
    out = subprocess.run(
        ["llvm-objdump", "-d", "--triple=mips64el", "--mcpu=mips3",
         "--no-show-raw-insn", "--start-address=0x%x" % start,
         "--stop-address=0x%x" % end, ELF],
        capture_output=True, text=True, check=True).stdout
    hi = {}
    for line in out.splitlines():
        m = re.match(r"\s*([0-9a-f]+):\s*(.*)", line)
        if not m:
            continue
        pc = int(m.group(1), 16)
        text = m.group(2).replace("\t", " ")
        word = read_word(elf, pc) or 0
        op = word >> 26
        rs, rt, imm = (word >> 21) & 31, (word >> 16) & 31, word & 0xFFFF
        if op in (0x1E, 0x1F):  # R5900 lq / sq
            text = "%s $%d, 0x%x($%d)" % ("lq" if op == 0x1E else "sq", rt, imm, rs)
        note = ""
        jump = re.search(r"\bjal\s+0x([0-9a-f]+)", text)
        if jump:
            target = int(jump.group(1), 16)
            note = by_addr.get(target, "func_%08X" % target)
        if op == 0x0F:  # lui
            hi[rt] = imm << 16
            note = "%#010x = %g" % (hi[rt], to_float(hi[rt]))
        elif op == 0x0D and rs in hi:  # ori after lui
            value = hi[rs] | imm
            note = "%#010x = %g" % (value, to_float(value))
        if pc in by_addr:
            print("\n%s:" % by_addr[pc])
        print("%06x: %-40s%s" % (pc, text, ("  ; " + note) if note else ""))


def to_float(word):
    return struct.unpack("<f", struct.pack("<I", word))[0]


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    names = load_names(EXE)
    if argv[1] == "--find":
        for start, end, name in names:
            if argv[2].lower() in name.lower():
                print("%#08x %#08x %s" % (start, end, name))
        return
    elf = load_elf(ELF)
    if argv[1] == "--word":
        for arg in argv[2:]:
            addr = int(arg, 16)
            word = read_word(elf, addr)
            print("%#08x: %#010x  int %d  float %g" % (
                addr, word, struct.unpack("<i", struct.pack("<I", word))[0],
                to_float(word)))
        return
    try:
        start = int(argv[1], 16)
        end = None
    except ValueError:
        match = [r for r in names if r[2] == argv[1]]
        if not match:
            sys.exit("no function named " + argv[1] + " (try --find)")
        start, end = match[0][0], match[0][1]
    if len(argv) > 2:
        end = int(argv[2], 16)
    if end is None:
        known = [r for r in names if r[0] == start]
        if known:
            end = known[0][1]
        else:
            later = [r[0] for r in names if r[0] > start]
            end = min(later) if later else start + 0x400
            print("(unnamed in the port's table: up to the next named "
                  "function, %#x; pass an end address to cut it)" % end)
    describe(elf, names, start, end)


if __name__ == "__main__":
    try:
        main(sys.argv)
    except BrokenPipeError:  # output piped to head
        sys.stderr.close()
