#!/usr/bin/env python3
"""
call_graph.py - Mappy's call graph with typed edges, and the call tree it implies.

Nodes are discover's routine entries (routines_full.txt) plus the vectors. Each node's control flow
is walked by emu-harness's descent.flow with every OTHER entry as a stop, so a routine's edges are
read from its own instructions only, never from a span sweep (which decoded data as code):

  call       JSR to another routine
  jmp        JMP abs to another routine (a tail call, or a jump back into a loop head)
  flows-into a path runs into another routine's entry: falls through, or branches into it
  dispatch   JMP (ind) through a jump table (jump_tables.txt), or a JSR to a shared JMP (ind)
             stub with the table loaded before it ($EA39): one edge per handler
  inline     JSR to an inline dispatcher (code_map.INLINE_DISPATCH): its word table's handlers
  task       the reset-time task switch ($C13B: switch_stack_and_jump_to_indexed_handler saves SP
             and jumps to the game task $C84F; swap_stack_pointer later trades stacks back, which
             no static edge can show)

Graph and order are emu_harness.passes.callgraph (Graph, sccs, leaves_first).

Writes: call_tree.txt (indented from each vector; a node already printed is shown once as
"(above)"), bottom_up_order.txt (leaves first, for the naming walk), callgraph.dot.
"""
import re
from pathlib import Path

from emu_harness.cpu.m6502.descent import flow
from emu_harness.passes.callgraph import Graph, sccs
from emu_harness.passes.native import dead_path
from code_map import HERE, INLINE_DISPATCH, PRG, WIN, label_names, table_lines

VEC = {0xC031: "RESET", 0xC2EF: "NMI", 0xC304: "IRQ"}
TASK_SITES = {0xC13B}          # jmp ($001E) after the stack switch: a task start, not a dispatch
ORDER = ["call", "jmp", "flows-into", "dispatch", "inline", "task"]

entries = sorted({int(l.strip()[1:], 16) for l in open(HERE / "routines_full.txt")} | set(VEC))
ent = set(entries)

NAMES = label_names()
NAMES.update({0xC031: NAMES.get(0xC031, "reset_cold_boot_init"), 0xC2EF: NAMES.get(0xC2EF, "nmi_sound_tick"),
              0xC304: NAMES.get(0xC304, "irq_rti_stub")})
def name(a): return NAMES.get(a, f"sub_{a:04X}")

tables, table_bytes = {}, set()
for line in table_lines(data=False):                      # dispatch tables only: their entries are code
    p = line.split(); site, base = int(p[0][1:], 16), int(p[1], 16)
    tables[site] = [int(x, 16) for x in p[2:]]
for line in table_lines():
    p = line.split(); base = int(p[1], 16)
    table_bytes |= {WIN.canon(base + k) for k in range(2 * (len(p) - 2))}

G = Graph("mappy")
for e in entries:
    G.subs[(0, e)] = name(e)
for e in entries:
    f = flow(WIN, e, data=frozenset(table_bytes | (ent - {e})), stop_brk=True, noreturn=frozenset(INLINE_DISPATCH))
    for site, t in f.calls.items():
        t = WIN.canon(t) if t in WIN else t
        if t in ent and t != e:
            G.add((0, e), (0, t), "call")
        if site in tables:                                  # inline table, or JSR to a JMP (ind) stub
            for h in tables[site]:
                G.add((0, e), (0, h), "inline" if t in INLINE_DISPATCH else "dispatch")
    for site, t in f.jumps.items():
        t = WIN.canon(t) if t in WIN else t
        if t in ent and t != e:
            G.add((0, e), (0, t), "jmp")
    for a, why in f.halts.items():                    # past an always-taken branch is no edge
        if why == "data" and a in ent and not dead_path(lambda x: PRG[(x - 0xC000) & 0x3FFF], f.starts, a):
            G.add((0, e), (0, a), "flows-into")
    for site in f.starts:
        if site in tables and site not in f.calls:          # a JMP (ind) site
            for h in tables[site]:
                if h in ent and h != e:
                    G.add((0, e), (0, h), "task" if site in TASK_SITES else "dispatch")
for v in VEC:
    G.roots[(0, v)].add(f"vector:{VEC[v]}")

succ = {e: [] for e in entries}
for (s, d), ks in G.edges.items():
    succ[s[1]].append((d[1], sorted(ks, key=ORDER.index)))
for e in succ:
    succ[e].sort()

# ---- the call tree: depth-first from each vector; a node is expanded once ----
shown, lines = set(), []
def walk(v, depth, kinds):
    tag = "" if not kinds else "  [" + ", ".join(k for k in kinds if k != "call") + "]" if kinds != ["call"] else ""
    if v in shown:
        lines.append("    " * depth + f"{name(v)}{tag}  (above)")
        return
    shown.add(v)
    lines.append("    " * depth + f"{name(v)}{tag}  ${v:04X}")
    for w, ks in succ[v]:
        walk(w, depth + 1, ks)
for v in VEC:
    lines.append(f"\n# {VEC[v]} vector")
    walk(v, 0, [])
unreached = [e for e in entries if e not in shown]
lines.append(f"\n# not reached from a vector by any edge kind: {len(unreached)}")
lines += [f"{name(e)}  ${e:04X}" for e in unreached]

# ---- leaves-first order for the naming walk ----
order = [v for c in sccs(entries, lambda v: [w for w, _ in succ[v]]) for v in c]
cycles = [c for c in sccs(entries, lambda v: [w for w, _ in succ[v]]) if len(c) > 1]

kinds = {}
for ks in G.edges.values():
    for k in ks:
        kinds[k] = kinds.get(k, 0) + 1
head = (f"# Mappy call tree (call_graph.py): {len(entries)} routines, {len(G.edges)} edges "
        f"({', '.join(f'{k} {kinds.get(k, 0)}' for k in ORDER)}); reached from the vectors: "
        f"{len(shown)}/{len(entries)}. [kinds] mark every edge that is not a plain JSR.")
(HERE / "call_tree.txt").write_text(head + "\n" + "\n".join(lines) + "\n", encoding="utf-8")
with open(HERE / "bottom_up_order.txt", "w") as f:
    f.write("# leaf-first (bottom-up) labeling order, from call_graph.py: name these first, propagate up\n")
    for v in order:
        f.write(f"${v:04X}  {name(v):44s} callees={len(succ[v])}{'  LEAF' if not succ[v] else ''}"
                f"{'  ' + VEC[v] if v in VEC else ''}\n")
with open(HERE / "callgraph.dot", "w") as f:
    f.write("digraph mappy {\n  rankdir=LR; node[shape=box,fontsize=8];\n")
    style = {"call": "", "jmp": " [style=dashed]", "flows-into": " [style=dotted]",
             "dispatch": " [color=red]", "inline": " [color=orange]", "task": " [color=blue,penwidth=2]"}
    for e in entries:
        f.write(f'  "{e:04X}"[label="{name(e)}\\n${e:04X}"];\n')
    for (s, d), ks in sorted(G.edges.items()):
        k = sorted(ks, key=ORDER.index)[-1]
        f.write(f'  "{s[1]:04X}" -> "{d[1]:04X}"{style[k]};\n')
    f.write("}\n")
import json
(HERE / "call_graph.json").write_text(json.dumps({
    "title": "Mappy (Japan)", "kinds": ORDER,
    "vectors": {f"{a:04X}": v for a, v in VEC.items()},
    "nodes": {f"{e:04X}": name(e) for e in entries},
    "edges": [[f"{s[1]:04X}", f"{d[1]:04X}", sorted(ks, key=ORDER.index)] for (s, d), ks in sorted(G.edges.items())],
}, indent=0), encoding="utf-8")
print(head)
print(f"recursion cycles (SCC > 1): {len(cycles)}")
print("wrote call_tree.txt, call_graph.json, bottom_up_order.txt, callgraph.dot")
