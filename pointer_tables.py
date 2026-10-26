#!/usr/bin/env python3
"""
pointer_tables.py - (b) find pointer tables structurally + cascade-connect the call graph.

The classification showed the 83 unreachable aren't a missing idiom -- 75 are propagation from
a few disconnected hubs, and the hubs are members of POINTER TABLES we hadn't located (the 2
unresolved dispatch sites + the music engine's tables, e.g. $F323).

A pointer table = a run of >=3 consecutive little-endian words that each point at decoded CODE
in $C000-$FFFF, sitting in bytes we did NOT decode as code (i.e. data). Find them, seed every
entry, connect each table to the routine whose code references its base (owner -> entries), and
re-measure. This is the structural complement to the idiom-based jump-table sweep.
The scan, the call-graph partition and the reachability are emu_harness.passes.native (row R).
"""
import re
from pathlib import Path

from emu_harness.passes.native import NativeMap, owner as _owner, partition_edges, pointer_runs, reachable
from code_map import HERE, INLINE_DISPATCH, WIN, table_lines

def cpu(a):  return M.canon(a)

seeds = {0xC031,0xC2EF,0xC304} | {int(l.strip()[1:],16) for l in open(HERE/"routines_full.txt")}
M = NativeMap(WIN, bytearray((HERE/"coverage_full2.bin").read_bytes() if (HERE/"coverage_full2.bin").exists()
                             else (HERE/"coverage_full.bin").read_bytes()), noreturn=INLINE_DISPATCH)
code, PRG = M.code, M.buf
known_tables = {}
for line in table_lines():
    p=line.split(); known_tables[int(p[0][1:],16)]=(int(p[1],16),[int(x,16) for x in p[2:]])
    M.mark_data(int(p[1],16), 2*(len(p)-2))

def fixpoint(seedset):
    return M.reach(seedset)[0]

routines = fixpoint(seeds)

# ---- scan DATA bytes for pointer-table runs (emu_harness.passes.native) ----
found_tables = pointer_runs(M)

ptr_targets={t for _,run in found_tables for t in run}
seeds.update(ptr_targets)
routines = fixpoint(seeds)
covered=sum(code)
new_tables=[t for t in found_tables if t[0] not in {cpu(s) for s,_ in known_tables.items()}]
print(f"pointer tables found in data: {len(found_tables)}  (covering {len(ptr_targets)} handlers)")
music=[t for t in found_tables if 0xF000<=t[0]<=0xF7FF]
print(f"  in music region $F000-$F7FF: {len(music)}  ->  {' '.join(f'${a:04X}x{len(r)}' for a,r in music)}")
print(f"routines: {len(routines)}   CODE: {covered:,}/16384 ({100*covered/0x4000:.1f}%)")

# ---- rebuild reachability: direct + indexed-tables + pointer-tables (owner-of-referencing-code) ----
entries=sorted({cpu(r) for r in routines}); ent=set(entries)
VEC={0xC031:"RESET",0xC2EF:"NMI",0xC304:"IRQ"}
def owner(a): return _owner(entries, a, M)
edges=partition_edges(M, entries)
for site,(base,ents) in known_tables.items():     # indexed dispatch
    o=owner(site)
    for h in ents:
        if h in ent and h!=o: edges[o].add(h)
# connect each pointer table to whoever references its base address as an operand
prgb=bytes(PRG)
for base,run in found_tables:
    needle=bytes([base&0xFF,(base>>8)&0xFF]); refs=[]; k=0
    while True:
        k=prgb.find(needle,k)
        if k<0: break
        if code[k]: refs.append(cpu(k))           # referenced from decoded code
        k+=1
    for r in refs:
        o=owner(r)
        for h in run:
            if h in ent and h!=o: edges[o].add(h)
seen=reachable(edges, set(VEC)&ent)
unreached=[e for e in entries if e not in seen]
print(f"\ncall graph: nodes={len(entries)} edges={sum(len(v) for v in edges.values())}")
print(f"reachable from 3 vectors: {len(seen)}/{len(entries)} ({100*len(seen)/len(entries):.0f}%)")
print(f"still unreachable: {len(unreached)}  {' '.join(f'${e:04X}' for e in unreached[:14])}{'...' if len(unreached)>14 else ''}")
# final code recall
asm=Path(r"C:\Users\Chris.Isaacson\Vault\raw\mappy_bank_FF.asm").read_text(encoding="utf-8",errors="replace")
repo=bytearray(0x4000)
for line in asm.splitlines():
    m=re.search(r'^([CD-]) ([CD-]) .*00:([0-9A-Fa-f]{4}):\s+((?:[0-9A-Fa-f]{2}\s)+)',line)
    if not m: continue
    if m.group(1)=='C':
        for k in range(len(m.group(4).split())):
            o=int(m.group(3),16)-0xC000+k
            if 0<=o<0x4000: repo[o]=1
rc=sum(repo); tp=sum(1 for i in range(0x4000) if code[i] and repo[i])
print(f"CODE recall vs repo: {100*tp/rc:.1f}%  ({tp}/{rc})")
