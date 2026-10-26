#!/usr/bin/env python3
"""
label_leaves.py - Phase B step 1: fingerprint the call-graph LEAVES for grounded naming.

A leaf = a routine that calls nothing (no JSR/JMP-abs/dispatch edge out). Leaves are the easy
base of the bottom-up labeling: their behavior is self-contained. For each we emit a deterministic
SIGNATURE (hardware regs touched, hot zero-page, control shape, size, #callers) + the disassembly.
We name from THAT -- never from the repo's labels (the repo stays an after-the-fact diff).
The call graph and the listing are emu_harness.passes.native (row R).

Hardware decoder (the NES register map is the spec/oracle; emu_harness machines/nes/memory.register_name):
  $2000-$2007 PPU | $4014 OAMDMA | $4000-$4013/$4015 APU | $4016-$4017 controller
"""
import sys
from pathlib import Path

from emu_harness.machines.nes.memory import register_name as hwname
from emu_harness.passes.native import NativeMap, owner as _owner, partition_edges, routine_listing
from code_map import HERE, INLINE_DISPATCH, WIN, table_lines

M = NativeMap(WIN, noreturn=INLINE_DISPATCH)
def norm(a): return M.off(a)

entries = sorted({0xC031,0xC2EF,0xC304} | {int(l.strip()[1:],16) for l in open(HERE/"routines_full.txt")})
ent = set(entries)
tables = {}
for line in table_lines():
    p=line.split(); tables[int(p[0][1:],16)]=(int(p[1],16),[int(x,16) for x in p[2:]])
is_data = M.is_data
for site,(base,e) in tables.items():
    M.mark_data(base, 2*len(e))
def owner(a): return _owner(entries, a, M)

# edges (direct + dispatch) -> callees & callers
edges = partition_edges(M, entries, skip_data=True)
for site,(base,hs) in tables.items():
    o=owner(site)
    for h in hs:
        if h in ent and h!=o: edges[o].add(h)
callers={e:set() for e in entries}
for a,ts in edges.items():
    for t in ts: callers[t].add(a)
leaves=[e for e in entries if not edges[e]]

def disasm_routine(e):
    return routine_listing(M, entries, e, hwname=hwname)

import re as _re
def load_labels():
    LAB={}
    if (HERE/"labels.toml").exists():
        cur=None
        for l in open(HERE/"labels.toml",encoding="utf-8"):
            m=_re.search(r'addr\s*=\s*"([0-9A-Fa-f]{4})"',l)
            if m: cur=int(m.group(1),16)
            m=_re.search(r'name\s*=\s*"([^"]+)"',l)
            if m and cur is not None: LAB[cur]=m.group(1); cur=None
        # also support my inline 'addr="X"; name="Y"' lines
        for l in open(HERE/"labels.toml",encoding="utf-8"):
            m=_re.search(r'addr\s*=\s*"([0-9A-Fa-f]{4})".*name\s*=\s*"([^"]+)"',l)
            if m: LAB[int(m.group(1),16)]=m.group(2)
    return LAB
LABELS=load_labels()

def emit_one(e):
    body,f=disasm_routine(e)
    if e in LABELS: print(f"; CURRENT NAME: {LABELS[e]}")
    print(f"; routine ${e:04X}  ({f['nbytes']} bytes, {f['ninstr']} instrs, {len(callers[e])} callers"
          f"{', has backward-loop' if f['loop'] else ''})")
    if f['hw']:  print("; hardware registers touched: "+", ".join(f['hw']))
    if f['zp']:  print("; zero-page touched: "+", ".join(f['zp']))
    if f['ram']: print("; RAM ($0000-$07FF) touched: "+", ".join(f['ram']))
    cnames=[f"${c:04X}={LABELS.get(c,'?')}" for c in sorted(edges[e])]
    print(f"; calls: {'(none — leaf)' if not edges[e] else ', '.join(cnames)}")
    print()
    for a,txt in body:
        m=_re.search(r'(jsr|jmp) \$([0-9a-f]{4})',txt)
        if m and int(m.group(2),16) in LABELS: txt+=f"   ; -> {LABELS[int(m.group(2),16)]}"
        print(f"${a:04X}: {txt}")

if __name__=="__main__":
    args=sys.argv[1:]
    if args and args[0]=="one":    # clean single-routine dump (for labeling agents)
        emit_one(int(args[1],0)); sys.exit()
    if args and args[0]=="leaves-remaining":   # JSON list of leaves lacking a label
        import json
        rem=[f"{e:04X}" for e in leaves if e not in LABELS and not is_data[norm(e)]]
        print(json.dumps(rem)); sys.exit()
    if args and args[0]=="frontier":   # JSON list of unlabeled routines whose callees are ALL labeled
        import json
        fr=[f"{e:04X}" for e in entries
            if e not in LABELS and not is_data[norm(e)] and edges[e]
            and all(c in LABELS for c in edges[e])]
        print(json.dumps(fr)); sys.exit()
    sel=None
    if args and args[0]=="show":   # full disasm for given addrs
        sel=[int(x,0) for x in args[1:]]
    print(f"# {len(leaves)} leaves (no callees)\n")
    for e in leaves:
        body,f=disasm_routine(e)
        ca=len(callers[e])
        sig=f"{f['nbytes']:3d}b {f['ninstr']:2d}i callers={ca:2d}"
        sig+= " LOOP" if f['loop'] else "    "
        sig+= ("  HW="+",".join(f['hw'])) if f['hw'] else ""
        sig+= ("  zp="+",".join(f['zp'][:6])) if f['zp'] else ""
        sig+= ("  ram="+",".join(f['ram'][:5])) if f['ram'] else ""
        print(f"${e:04X}  {sig}")
        if sel is not None and e in sel:
            for a,txt in body: print(f"        ${a:04X}: {txt}")
            print()
