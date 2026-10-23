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

The descent is emu_harness's shared walker via code_map.py (emu-harness MIGRATION.md row B);
the jump-table finder below is still Mappy's (row R).
"""
import re

from emu_harness.cpu.m6502.disasm import OPS
from code_map import HERE, PRG, reach

def norm(a): return a & 0x3FFF                    # $8000/$C000 -> 0..0x3FFF
def cpu(a): return 0xC000 + norm(a)              # canonical CPU addr
def in_code_region(a): return 0xC000 <= a <= 0xFFFF or 0x8000 <= a <= 0xBFFF
def legal(a): return PRG[norm(a)] in OPS         # byte at a is a documented opcode

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
all_routines, _ = reach(seeds, is_data, code)

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
        f.write(f"${r:04X}\n")
print("wrote coverage_static.bin, routines.txt")
