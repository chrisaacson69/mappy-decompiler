#!/usr/bin/env python3
"""
stored_pointers.py - (a) the SECOND dispatch idiom: stored function pointers.

Pattern ("install a handler into a state variable", then JMP (var) elsewhere):
    LDA #<routine   (A9 lo)
    STA ptr         (85 zp  | 8D abs)
    LDA #>routine   (A9 hi)
    STA ptr+1       (85 zp+1| 8D abs+1)
The handler is set by DATA FLOW, not an indexed table, so the indexed-table sweep can't see
it. We scan covered code for adjacent LDA#/STA pairs whose two immediates form a code pointer,
seed those handlers, and add `installer -> handler` edges. Then re-measure coverage + the call
graph's reachability. Builds on coverage_full / routines_full / jump_tables from the sweep.
The scan, the call-graph partition and the reachability are emu_harness.passes.native (row R).
"""
from emu_harness.cpu.m6502.disasm import MODE_LEN, OPS
from emu_harness.passes.native import (NativeMap, owner as _owner, partition_edges, reachable,
                                       stored_pointer_installs)
from code_map import HERE, WIN

def cpu(a):  return M.canon(a)

seeds = {0xC031,0xC2EF,0xC304}
seeds.update(int(l.strip()[1:],16) for l in open(HERE/"routines_full.txt"))
M = NativeMap(WIN, bytearray((HERE/"coverage_full.bin").read_bytes()))
code = M.code
# mark known jump-table bytes as data so descent won't decode them
tables = {}
for line in open(HERE/"jump_tables.txt"):
    p=line.split(); site=int(p[0][1:],16); base=int(p[1],16); ents=[int(x,16) for x in p[2:]]
    tables[site]=(base,ents)
    M.mark_data(base, 2*len(ents))

starts = {}
def fixpoint(seedset):
    routines, st = M.reach(seedset)
    for a in st:
        op=M.byte(a); starts[M.off(a)]=(op,1+MODE_LEN[OPS[op][1]])
    return routines

routines = fixpoint(seeds)

# ---- LDA#/STA pairs forming a code pointer (emu_harness.passes.native) ----
installs = stored_pointer_installs(M, starts)

ptr_targets = {c for _,c in installs}
new = ptr_targets - {cpu(r) for r in routines}
seeds.update(ptr_targets)
routines = fixpoint(seeds)
covered=sum(code)

print(f"stored-pointer installs found : {len(installs)}  (distinct handlers: {len(ptr_targets)})")
print(f"  new routines from this idiom : {len(new)}  {' '.join(f'${c:04X}' for c in sorted(new)[:10])}{'...' if len(new)>10 else ''}")
prev=sum((HERE/'coverage_full.bin').read_bytes())
print(f"routines: {len(routines)}   CODE: {covered:,}/16384 ({100*covered/0x4000:.1f}%)  (was {100*prev/0x4000:.1f}%)")

# ---- rebuild call-graph reachability: direct + indexed-table + stored-pointer edges ----
entries=sorted(c for c in {cpu(r) for r in routines})
ent=set(entries); VEC={0xC031:"RESET",0xC2EF:"NMI",0xC304:"IRQ"}
def owner(a): return _owner(entries, a, M)
edges=partition_edges(M, entries)
for site,(base,ents) in tables.items():            # indexed-table dispatch edges
    o=owner(site)
    for h in ents:
        if h in ent and h!=o: edges[o].add(h)
for site,tgt in installs:                          # stored-pointer install edges
    o=owner(site)
    if tgt in ent and tgt!=o: edges[o].add(tgt)
seen=reachable(edges, set(VEC)&ent)
unreached=[e for e in entries if e not in seen]
print(f"\ncall graph: nodes={len(entries)} edges={sum(len(v) for v in edges.values())}")
print(f"reachable from 3 vectors: {len(seen)}/{len(entries)} ({100*len(seen)/len(entries):.0f}%)")
print(f"still unreachable: {len(unreached)}  {' '.join(f'${e:04X}' for e in unreached[:12])}{'...' if len(unreached)>12 else ''}")
(HERE/"coverage_full2.bin").write_bytes(bytes(code))
