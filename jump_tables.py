#!/usr/bin/env python3
"""
jump_tables.py - the keystone: find ALL dispatch tables statically, finishing the code
map AND the call graph in one pass.

Mappy's dispatch idiom (invariant, learned from the 4 known sites):
    LDA table,X      (BD lo hi)   ; low byte of handler pointer
    STA ptr          (85 zp)
    LDA table+1,X    (BD lo hi)   ; high byte
    STA ptr+1        (85 zp)
    JMP (ptr)        (6C zp 00)   ; <- the dispatch site

So: descend to mark code -> find every JMP-(ind) (0x6C) at an instruction boundary ->
back-scan to the indexed LDA that loads its pointer -> that operand is the table base ->
read the word array to its end. Seed all handlers, mark the table bytes DATA, recurse.
This finds tables the demo never executed (bonus $E17A via the un-taken $DA29 site).
"""
import re

from emu_harness.passes.native import NativeMap, dispatch_tables
from code_map import HERE, WIN

def in_code(a): return 0xC000 <= a <= 0xFFFF or 0x8000 <= a <= 0xBFFF

# seeds = dynamic targets + vectors
seeds = {0xC2EF,0xC031,0xC304}
for line in open(HERE / "codegraph.txt"):
    m = re.match(r'\s*\$([0-9A-F]{4})\s*$', line)
    if m: seeds.add(int(m.group(1),16))
    m = re.match(r'\s*\$([0-9A-F]{4}) -> (.+)', line)
    if m and 'JMP' not in line:
        seeds.update(int(x[1:],16) for x in m.group(2).split() if in_code(int(x[1:],16)))

M = NativeMap(WIN, bytearray((HERE / "coverage.bin").read_bytes()))
code = M.code
# ---- iterate: descend -> find sites -> resolve+seed tables -> repeat (emu_harness.passes.native) ----
tables, known_sites, routines, _ = dispatch_tables(M, seeds)
cpu = M.canon
covered=sum(code)
print(f"dispatch sites (JMP indirect): {len(known_sites)}")
print(f"jump tables resolved          : {len(tables)}")
for site,(base,ents) in sorted(tables.items()):
    print(f"  site ${site:04X} -> table ${base:04X} x{len(ents):2d}  e.g. {' '.join(f'${e:04X}' for e in ents[:4])}{' ...' if len(ents)>4 else ''}")
prev=sum((HERE/'coverage.bin').read_bytes())
print(f"\nroutines: {len(routines)}    CODE: {covered:,}/16384 ({100*covered/0x4000:.1f}%)   (was {100*prev/0x4000:.1f}% dynamic)")
(HERE/"coverage_full.bin").write_bytes(bytes(code))
# save tables for the call graph
with open(HERE/"jump_tables.txt","w") as f:
    for site,(base,ents) in sorted(tables.items()):
        f.write(f"${site:04X} {base:04X} " + " ".join(f"{e:04X}" for e in ents) + "\n")
with open(HERE/"routines_full.txt","w") as f:
    for r in sorted(routines):
        if in_code(r): f.write(f"${cpu(r):04X}\n")
print("wrote coverage_full.bin, jump_tables.txt, routines_full.txt")
