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
"""
import re, sys, bisect
from pathlib import Path
sys.path.insert(0, r"C:\Users\Chris.Isaacson\koei-nes\tools")
import disasm6502
OPS, MODE_LEN = disasm6502.OPS, disasm6502.MODE_LEN

HERE = Path(__file__).parent
PRG = (HERE / "Mappy (Japan).nes").read_bytes()[16:16 + 0x4000]
def norm(a): return a & 0x3FFF
def cpu(a):  return 0xC000 + norm(a)
def inc(a):  return 0xC000 <= a <= 0xFFFF or 0x8000 <= a <= 0xBFFF
def legal(a):return PRG[norm(a)] in OPS
BR = {0x10,0x30,0x50,0x70,0x90,0xB0,0xD0,0xF0}

seeds = {0xC031,0xC2EF,0xC304}
seeds.update(int(l.strip()[1:],16) for l in open(HERE/"routines_full.txt"))
code = bytearray((HERE/"coverage_full.bin").read_bytes())
is_data = bytearray(0x4000)
# mark known jump-table bytes as data so descent won't decode them
tables = {}
for line in open(HERE/"jump_tables.txt"):
    p=line.split(); site=int(p[0][1:],16); base=int(p[1],16); ents=[int(x,16) for x in p[2:]]
    tables[site]=(base,ents)
    for k in range(len(ents)): is_data[norm(base+2*k)]=is_data[norm(base+2*k+1)]=1

starts = {}
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
            seen.add(n); starts[n]=(op,ilen)
            if op in BR:
                off=PRG[norm(pc+1)]; off-=0x100 if off>=0x80 else 0
                t=(pc+2+off)&0xFFFF
                if inc(t): stack.append(t)
                pc=(pc+2)&0xFFFF; continue
            if op==0x20:
                t=PRG[norm(pc+1)]|(PRG[norm(pc+2)]<<8)
                if inc(t): found.add(t)
                pc=(pc+3)&0xFFFF; continue
            if op==0x4C:
                t=PRG[norm(pc+1)]|(PRG[norm(pc+2)]<<8)
                if inc(t): found.add(t)
                break
            if op in (0x60,0x40,0x00,0x6C): break
            pc=(pc+ilen)&0xFFFF
    return found

def fixpoint(seedset):
    work=set(seedset); routines=set(seedset)
    while work:
        nxt=set()
        for e in work:
            for t in descend(e):
                if t not in routines: nxt.add(t)
        routines|=nxt; work=nxt
    return routines

routines = fixpoint(seeds)

# ---- scan for LDA#/STA pairs at instruction boundaries ----
ordered = sorted(starts)
# event = (addr, sta_target, imm) for "LDA #imm" immediately followed by "STA zp|abs"
events=[]
for i,n in enumerate(ordered):
    op,ilen = starts[n]
    if op!=0xA9: continue                 # LDA #imm
    imm = PRG[norm(n+1)]
    s2 = n+ilen
    if norm(s2) not in starts: continue
    op2,_ = starts[norm(s2)]
    if op2==0x85:   tgt = PRG[norm(s2+1)]                       # STA zp
    elif op2==0x8D: tgt = PRG[norm(s2+1)]|(PRG[norm(s2+2)]<<8)  # STA abs
    else: continue
    events.append((cpu(n), tgt, imm))

# pair events with consecutive targets (t,t+1) that are close in address
installs=[]   # (installer_addr, ptr_target_routine)
by_addr = sorted(events)
for j,(a,t,imm) in enumerate(by_addr):
    for k in range(j+1, min(j+6, len(by_addr))):
        a2,t2,imm2 = by_addr[k]
        if a2-a > 16: break
        lo=hi=None; base_site=a
        if t2==t+1: lo,hi=imm,imm2          # low then high
        elif t2==t-1: lo,hi=imm2,imm        # high then low
        else: continue
        p=lo|(hi<<8)
        # accept p (or p+1 for the addr-1 convention) if it's a code routine
        for cand in (p, (p+1)&0xFFFF):
            if inc(cand) and legal(cand):
                installs.append((base_site, cand)); break
        break

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
def owner(a):
    a=cpu(a); i=bisect.bisect_right(entries,a)-1; return entries[i]
edges={e:set() for e in entries}
for idx,e in enumerate(entries):
    end=entries[idx+1] if idx+1<len(entries) else 0x10000
    pc=e
    while pc<end:
        op=PRG[norm(pc)]
        if op not in OPS: pc+=1; continue
        ilen=1+MODE_LEN.get(OPS[op][1],0)
        if op in (0x20,0x4C):
            t=PRG[norm(pc+1)]|(PRG[norm(pc+2)]<<8)
            if t in ent and t!=e: edges[e].add(t)
        pc+=ilen
for site,(base,ents) in tables.items():            # indexed-table dispatch edges
    o=owner(site)
    for h in ents:
        if h in ent and h!=o: edges[o].add(h)
for site,tgt in installs:                          # stored-pointer install edges
    o=owner(site)
    if tgt in ent and tgt!=o: edges[o].add(tgt)
callers={e:set() for e in entries}
for a,ts in edges.items():
    for t in ts: callers[t].add(a)
from collections import deque
seen=set(VEC)&ent; dq=deque(seen)
while dq:
    v=dq.popleft()
    for w in edges[v]:
        if w not in seen: seen.add(w); dq.append(w)
unreached=[e for e in entries if e not in seen]
print(f"\ncall graph: nodes={len(entries)} edges={sum(len(v) for v in edges.values())}")
print(f"reachable from 3 vectors: {len(seen)}/{len(entries)} ({100*len(seen)/len(entries):.0f}%)")
print(f"still unreachable: {len(unreached)}  {' '.join(f'${e:04X}' for e in unreached[:12])}{'...' if len(unreached)>12 else ''}")
(HERE/"coverage_full2.bin").write_bytes(bytes(code))
