#!/usr/bin/env python3
"""
call_graph.py - build and walk Mappy's call graph from the Phase-A code map.

Nodes  = the discovered routine entries (routines.txt).
Edges  = caller -> callee, by attributing each JSR/JMP-abs instruction to its OWNING routine
         (the greatest entry <= the instruction's address -- the standard contiguous partition),
         plus the jump-table dispatch fan-outs (site's owner -> each handler).
Walk   = roots (no callers), leaves (no callees), depth from the 3 vectors, SCCs (recursion),
         and the LEAF-FIRST topological order == the Phase-B bottom-up labeling sequence.
"""
import re, sys
from pathlib import Path
from emu_harness.cpu.m6502 import disasm as disasm6502   # the shared 6502 tables (emu-harness rows B / H2)
OPS, MODE_LEN = disasm6502.OPS, disasm6502.MODE_LEN

HERE = Path(__file__).parent
PRG = (HERE / "Mappy (Japan).nes").read_bytes()[16:16 + 0x4000]
def norm(a): return a & 0x3FFF
def cpu(a):  return 0xC000 + norm(a)

entries = sorted(int(l.strip()[1:], 16) for l in open(HERE / "routines.txt"))
ent_set = set(entries)
VEC = {0xC031: "RESET", 0xC2EF: "NMI", 0xC304: "IRQ"}

# owner(addr) = greatest entry <= addr
import bisect
def owner(a):
    a = cpu(a); i = bisect.bisect_right(entries, a) - 1
    return entries[i] if i >= 0 else entries[0]

# jump tables (from static_expand output, re-derive sites->handlers)
indirect = {}
for line in open(HERE / "codegraph.txt"):
    m = re.match(r'\s*\$([0-9A-F]{4}) -> (.+)', line)
    if m and 'JMP' not in line:
        indirect[int(m.group(1),16)] = [int(x[1:],16) for x in m.group(2).split()]

edges = {e: set() for e in entries}     # entry -> set of callee entries
labels = {}                             # edge label hint (call/jump/dispatch)

# walk each routine's byte span, record JSR/JMP-abs edges
for idx, e in enumerate(entries):
    end = entries[idx+1] if idx+1 < len(entries) else 0x10000
    end = min(cpu(end), 0x10000)
    pc = cpu(e)
    while pc < end:
        op = PRG[norm(pc)]
        if op not in OPS: pc += 1; continue
        ilen = 1 + MODE_LEN.get(OPS[op][1], 0)
        if op in (0x20, 0x4C):                      # JSR / JMP abs
            tgt = PRG[norm(pc+1)] | (PRG[norm(pc+2)] << 8)
            if tgt in ent_set and tgt != e:
                edges[e].add(tgt)
        pc += ilen

# dispatch fan-out: owner(site) -> each handler
for site, handlers in indirect.items():
    o = owner(site)
    for h in handlers:
        if h in ent_set and h != o:
            edges[o].add(h); labels[(o,h)] = "dispatch"

# ---- graph metrics ----
callees = edges
callers = {e: set() for e in entries}
for a, ts in edges.items():
    for t in ts: callers[t].add(a)

roots  = [e for e in entries if not callers[e]]
leaves = [e for e in entries if not callees[e]]
n_edges = sum(len(v) for v in edges.values())

# SCCs (Tarjan) to find recursion/cycles -- emu-harness passes/callgraph (row H2; this file's algorithm)
from emu_harness.passes.callgraph import sccs as _sccs
sccs = _sccs(entries, lambda v: callees[v])
cycles = [c for c in sccs if len(c) > 1]

# leaf-first topological order (condense SCCs, reverse-topo) == bottom-up labeling order
scc_id = {}
for i,c in enumerate(sccs):
    for v in c: scc_id[v]=i
# sccs from Tarjan are already in reverse-topological order (leaves first)
bottom_up = [v for c in sccs for v in c]

# depth (shortest hops) from the 3 vectors
from collections import deque
depth = {}
dq = deque((v,0) for v in VEC if v in ent_set)
for v,_ in list(dq): depth[v]=0
while dq:
    v,d = dq.popleft()
    for w in callees[v]:
        if w not in depth: depth[w]=d+1; dq.append((w,d+1))
reachable = len(depth); maxdepth = max(depth.values()) if depth else 0

print(f"nodes (routines) : {len(entries)}")
print(f"edges (calls)    : {n_edges}")
print(f"roots (no caller): {len(roots)}   {' '.join(f'${r:04X}'+(f'/{VEC[r]}' if r in VEC else '') for r in roots[:12])}{' ...' if len(roots)>12 else ''}")
print(f"leaves (no callee): {len(leaves)}")
print(f"reachable from 3 vectors: {reachable}/{len(entries)}   max call depth: {maxdepth}")
print(f"recursion cycles (SCC>1): {len(cycles)}   {cycles[:3] if cycles else ''}")
print(f"unreachable-from-vectors: {len(entries)-reachable}")

# save artifacts
with open(HERE / "callgraph.dot","w") as f:
    f.write("digraph mappy {\n  rankdir=LR; node[shape=box,fontsize=8];\n")
    for e in entries:
        nm = VEC.get(e,""); f.write(f'  "{e:04X}"[label="{e:04X}{(" "+nm) if nm else ""}"];\n')
    for a,ts in edges.items():
        for t in ts:
            style=' [color=red]' if labels.get((a,t))=="dispatch" else ''
            f.write(f'  "{a:04X}" -> "{t:04X}"{style};\n')
    f.write("}\n")
with open(HERE / "bottom_up_order.txt","w") as f:
    f.write("# leaf-first (bottom-up) labeling order: label these first, propagate up\n")
    for v in bottom_up:
        deg=len(callees[v])
        f.write(f"${cpu(v):04X}  callees={deg} callers={len(callers[v])}"
                f"{'  LEAF' if deg==0 else ''}{'  '+VEC[v] if v in VEC else ''}\n")
print("wrote callgraph.dot, bottom_up_order.txt")

# show the top of each vector's call tree (depth-limited)
def tree(root, maxd=2):
    out=[]; seen=set()
    def rec(v,d,pre):
        if v in seen and d>0: out.append(pre+f"${cpu(v):04X} ...(seen)"); return
        seen.add(v); tag=VEC.get(v,"")
        out.append(pre+f"${cpu(v):04X}{' '+tag if tag else ''} ({len(callees[v])} callees)")
        if d<maxd:
            for w in sorted(callees[v]): rec(w,d+1,pre+"  ")
    rec(root,0,""); return out
for r in (0xC031,0xC2EF,0xC304):
    if r in ent_set:
        print(f"\n--- call tree from {VEC[r]} (${r:04X}), depth 2 ---")
        print("\n".join(tree(r)[:18]))
