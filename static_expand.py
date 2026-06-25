#!/usr/bin/env python3
"""
static_expand.py - Phase A part 2: expand the dynamic skeleton by recursive-descent.

Input : the 132 verified seeds + 4 jump-table sites from trace_codegraph.py (codegraph.txt),
        plus coverage.bin (dynamic CODE map).
Method: recursive-descent from every seed -- follow BOTH sides of each branch, follow JSR
        targets (and fall through past the call), follow JMP abs, stop on RTS/RTI/BRK/JMP(ind)
        and on any ILLEGAL opcode (the data guard -- we wandered out of code). Then locate each
        jump table (the contiguous word-array of code pointers feeding an indirect site) and add
        ALL its entries as seeds -- including the handlers the demo never triggered. Iterate to
        a fixpoint. Mark table bytes as DATA so descent never decodes them as instructions.

The disasm6502 OPS table is the ISA spec (lengths + which opcodes are control flow).
"""
import sys, re
from pathlib import Path
sys.path.insert(0, r"C:\Users\Chris.Isaacson\koei-nes\tools")
import disasm6502
OPS, MODE_LEN, REL = disasm6502.OPS, disasm6502.MODE_LEN, disasm6502.REL

HERE = Path(__file__).parent
PRG = (HERE / "Mappy (Japan).nes").read_bytes()[16:16 + 0x4000]
def norm(a): return a & 0x3FFF                    # $8000/$C000 -> 0..0x3FFF
def cpu(a): return 0xC000 + norm(a)              # canonical CPU addr
def in_code_region(a): return 0xC000 <= a <= 0xFFFF or 0x8000 <= a <= 0xBFFF
def legal(a): return PRG[norm(a)] in OPS         # byte at a is a documented opcode

BRANCHES = {0x10, 0x30, 0x50, 0x70, 0x90, 0xB0, 0xD0, 0xF0}

# ---- load dynamic results ----
seeds, indirect_sites = set(), {}
for line in open(HERE / "codegraph.txt"):
    m = re.match(r'\s*\$([0-9A-F]{4}) -> (.+)', line)        # indirect site -> targets
    if m and '->' in line and 'JMP' not in line:
        site = int(m.group(1), 16)
        tg = [int(x[1:], 16) for x in m.group(2).split()]
        indirect_sites[site] = tg
        seeds.update(t for t in tg if in_code_region(t))
        continue
    m = re.match(r'\s*\$([0-9A-F]{4})\s*$', line)            # direct target
    if m: seeds.add(int(m.group(1), 16))
seeds.update({0xC2EF, 0xC031, 0xC304})                        # the 3 vectors

code = bytearray((HERE / "coverage.bin").read_bytes())       # dynamic CODE map
is_data = bytearray(0x4000)                                   # bytes proven to be table DATA


def find_table(site, known_targets):
    """Find the contiguous word-array of code pointers feeding `site`; return (start,count)."""
    if not known_targets: return None
    # locate the first known target as a little-endian word in PRG
    t0 = known_targets[0] & 0xFFFF
    needle = bytes([t0 & 0xFF, (t0 >> 8) & 0xFF])
    best = None
    start = 0
    while True:
        i = bytes(PRG).find(needle, start)
        if i < 0: break
        if i % 1 == 0:
            # grow left/right while words are valid code pointers
            lo = i
            while lo - 2 >= 0:
                w = PRG[lo-2] | (PRG[lo-1] << 8)
                if in_code_region(w) and legal(w): lo -= 2
                else: break
            hi = i
            while hi + 2 <= 0x4000:
                w = PRG[hi] | (PRG[hi+1] << 8)
                if in_code_region(w) and legal(w): hi += 2
                else: break
            cnt = (hi - lo) // 2
            # accept the run that contains the most known targets
            words = {PRG[lo+2*k] | (PRG[lo+2*k+1] << 8) for k in range(cnt)}
            score = len(set(known_targets) & words)
            if best is None or score > best[2]:
                best = (lo, cnt, score)
        start = i + 1
    return best


def descend(entry):
    """Recursive-descent from one entry; mark code; return newly found JSR/JMP targets."""
    found = set()
    stack = [entry]
    seen = set()
    while stack:
        pc = stack.pop()
        while True:
            n = norm(pc)
            if n in seen: break
            if is_data[n]: break
            op = PRG[n]
            if op not in OPS:                 # ILLEGAL -> data guard: stop this path
                break
            ilen = 1 + MODE_LEN.get(OPS[op][1], 0)
            for k in range(ilen): code[norm(pc + k)] = 1
            seen.add(n)
            if op in BRANCHES:                # REL: take both sides
                off = PRG[norm(pc + 1)]; off -= 0x100 if off >= 0x80 else 0
                tgt = (pc + 2 + off) & 0xFFFF
                if in_code_region(tgt): stack.append(tgt)
                pc = (pc + 2) & 0xFFFF; continue
            if op == 0x20:                    # JSR: record callee, fall through
                tgt = PRG[norm(pc+1)] | (PRG[norm(pc+2)] << 8)
                if in_code_region(tgt): found.add(tgt)
                pc = (pc + 3) & 0xFFFF; continue
            if op == 0x4C:                    # JMP abs: follow, no fall-through
                tgt = PRG[norm(pc+1)] | (PRG[norm(pc+2)] << 8)
                if in_code_region(tgt): found.add(tgt)
                break
            if op in (0x60, 0x40, 0x00, 0x6C):  # RTS/RTI/BRK/JMP(ind): terminate
                break
            pc = (pc + ilen) & 0xFFFF
    return found


# ---- mark jump tables as DATA + add their full entry lists as seeds ----
tables = {}
for site, tg in indirect_sites.items():
    res = find_table(site, tg)
    if res:
        lo, cnt, score = res
        tables[site] = (cpu(lo), cnt)
        for k in range(cnt):
            w = PRG[lo+2*k] | (PRG[lo+2*k+1] << 8)
            if in_code_region(w): seeds.add(w)
            is_data[norm(lo + 2*k)] = is_data[norm(lo + 2*k + 1)] = 1

# ---- fixpoint recursive-descent ----
work = set(seeds); all_routines = set(seeds)
while work:
    nxt = set()
    for e in work:
        for t in descend(e):
            if t not in all_routines: nxt.add(t)
    all_routines |= nxt
    work = nxt

covered = sum(code)
print(f"jump tables located: {len(tables)}")
for site, (addr, cnt) in sorted(tables.items()):
    print(f"  site ${site:04X} -> table ${addr:04X} x{cnt} entries")
print(f"routines (entries) : {len(all_routines)}")
print(f"CODE bytes         : {covered:,} / 16384  ({100*covered/0x4000:.1f}% of PRG)")
prev = sum((HERE / 'coverage.bin').read_bytes())
print(f"  (dynamic was {prev:,} = {100*prev/0x4000:.1f}%; static added {covered-prev:,})")
(HERE / "coverage_static.bin").write_bytes(bytes(code))
with open(HERE / "routines.txt", "w") as f:
    for r in sorted(all_routines):
        if in_code_region(r): f.write(f"${0xC000 + norm(r):04X}\n")
print("wrote coverage_static.bin, routines.txt")
