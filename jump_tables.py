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
import re, sys
from pathlib import Path
sys.path.insert(0, r"C:\Users\Chris.Isaacson\koei-nes\tools")
import disasm6502
OPS, MODE_LEN = disasm6502.OPS, disasm6502.MODE_LEN

HERE = Path(__file__).parent
PRG = (HERE / "Mappy (Japan).nes").read_bytes()[16:16 + 0x4000]
def norm(a): return a & 0x3FFF
def cpu(a):  return 0xC000 + norm(a)
def in_code(a): return 0xC000 <= a <= 0xFFFF or 0x8000 <= a <= 0xBFFF
def legal(a): return PRG[norm(a)] in OPS
BRANCHES = {0x10,0x30,0x50,0x70,0x90,0xB0,0xD0,0xF0}

# seeds = dynamic targets + vectors
seeds = {0xC2EF,0xC031,0xC304}
for line in open(HERE / "codegraph.txt"):
    m = re.match(r'\s*\$([0-9A-F]{4})\s*$', line)
    if m: seeds.add(int(m.group(1),16))
    m = re.match(r'\s*\$([0-9A-F]{4}) -> (.+)', line)
    if m and 'JMP' not in line:
        seeds.update(int(x[1:],16) for x in m.group(2).split() if in_code(int(x[1:],16)))

code = bytearray((HERE / "coverage.bin").read_bytes())
is_data = bytearray(0x4000)
starts = {}           # instruction-start addr (norm) -> opcode
ptr_of = {}           # JMP-(ind) site norm -> zp pointer operand

def descend(entry):
    found=set(); stack=[entry]; seen=set()
    while stack:
        pc=stack.pop()
        while True:
            n=norm(pc)
            if n in seen or is_data[n]: break
            op=PRG[n]
            if op not in OPS: break
            ilen=1+MODE_LEN.get(OPS[op][1],0)
            for k in range(ilen): code[norm(pc+k)]=1
            seen.add(n); starts[n]=op
            if op in BRANCHES:
                off=PRG[norm(pc+1)]; off-=0x100 if off>=0x80 else 0
                t=(pc+2+off)&0xFFFF
                if in_code(t): stack.append(t)
                pc=(pc+2)&0xFFFF; continue
            if op==0x20:                       # JSR
                t=PRG[norm(pc+1)]|(PRG[norm(pc+2)]<<8)
                if in_code(t): found.add(t)
                pc=(pc+3)&0xFFFF; continue
            if op==0x4C:                       # JMP abs
                t=PRG[norm(pc+1)]|(PRG[norm(pc+2)]<<8)
                if in_code(t): found.add(t)
                break
            if op==0x6C:                       # JMP (ind) -- dispatch site
                ptr_of[n]=PRG[norm(pc+1)]|(PRG[norm(pc+2)]<<8)
                break
            if op in (0x60,0x40,0x00): break   # RTS/RTI/BRK
            pc=(pc+ilen)&0xFFFF
    return found

def fixpoint_descend(seedset):
    work=set(seedset); routines=set(seedset)
    while work:
        nxt=set()
        for e in work:
            for t in descend(e):
                if t not in routines: nxt.add(t)
        routines|=nxt; work=nxt
    return routines

def resolve_table(site_n):
    """back-scan instruction starts before site for the indexed LDA feeding the pointer's
    LOW byte (its STA target == the JMP pointer's low byte) -- that operand is the table base."""
    ptr = ptr_of.get(site_n)
    site = cpu(site_n)
    cand = [cpu(a) for a in starts if 0 < (site - cpu(a)) <= 30]
    loads = []   # (base, sta_target) for each indexed-abs load, nearest first
    for a in sorted(cand, reverse=True):
        op = PRG[norm(a)]
        if op in (0xBD, 0xB9):                              # LDA abs,X / abs,Y
            base = PRG[norm(a+1)] | (PRG[norm(a+2)] << 8)
            sta_t = PRG[norm(a+4)] if PRG[norm(a+3)] == 0x85 else None  # STA zp after it
            loads.append((base, sta_t))
    if ptr is not None:                                     # prefer the low-byte (base) load
        for base, sta_t in loads:
            if sta_t == (ptr & 0xFF):
                return base
    return loads[0][0] if loads else None

def read_table(base, max_entries=64):
    ents=[]; a=base
    for _ in range(max_entries):
        if is_data[norm(a)] and a!=base: break
        w=PRG[norm(a)]|(PRG[norm(a+1)]<<8)
        if in_code(w) and legal(w):
            ents.append(w); a+=2
        else: break
    return ents

# ---- iterate: descend -> find sites -> resolve+seed tables -> repeat ----
tables={}; known_sites=set()
while True:
    routines = fixpoint_descend(seeds)
    new=False
    for n,op in list(starts.items()):
        if op==0x6C and n not in known_sites:
            known_sites.add(n)
            base=resolve_table(n)
            if base is None: continue
            ents=read_table(base)
            if not ents: continue
            tables[cpu(n)]=(base,ents)
            for e in range(len(ents)): is_data[norm(base+2*e)]=is_data[norm(base+2*e+1)]=1
            before=len(seeds); seeds.update(e for e in ents if in_code(e))
            if len(seeds)>before: new=True
    if not new: break

routines = fixpoint_descend(seeds)
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
