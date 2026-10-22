#!/usr/bin/env python3
"""
mappy_mlb.py - project labels.toml + vars.toml onto a Mesen 2 .mlb label file.

Reads Mappy's own registry schema ([[...]] blocks); locating and writing are emu-harness's
(machines.nes.memory.locate, backends.mesen.labels), so the file is in Mesen's own export format.
Mappy is NROM-128 (16K mirrored); the cartridge facts come from the ROM header.
Object-record fields are written onto the $0400 base object (object 0) as the record template.
Output: "Mappy (Japan).mlb" beside the ROM, so Mesen auto-loads it by basename.
"""
import re
from pathlib import Path

from emu_harness.backends.mesen.labels import write_mlb  # pip install -e ../emu-harness
from emu_harness.core.symbols import Symbol
from emu_harness.machines.nes.memory import Cart, locate

HERE = Path(__file__).parent
ROM = HERE / "Mappy (Japan).nes"
CART = Cart.from_ines(ROM)

def flat(s, n=140):
    s = re.sub(r'\s+', ' ', s or '').strip()
    return s[:n]

def parse_blocks(text):
    """yield dicts of key->value for each [[...]] block. Handles BOTH the multi-line
    form (one key=value per line) and the inline form (addr="X"; name="Y"; ... on one line)."""
    cur=None
    for line in text.splitlines():
        if re.match(r'\s*\[\[', line):
            if cur: yield cur
            cur={}
        elif cur is not None:
            for k,v in re.findall(r'(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"', line):  # ALL pairs on the line
                cur[k]=v.replace('\\"','"').replace('\\\\','\\')
    if cur: yield cur

lines=[]
# --- functions -> NesPrgRom ---
nf=0
for b in parse_blocks((HERE/"labels.toml").read_text(encoding="utf-8")):
    if "addr" not in b or "name" not in b: continue
    a=int(b["addr"],16)
    if not (0xC000<=a<=0xFFFF): continue
    cmt=f"[{b.get('conf','')}] {flat(b.get('why',''))}"
    lines.append(Symbol(*locate(CART, "prg.bank0", a), b['name'], cmt)); nf+=1
# --- variables -> NesInternalRam / NesSaveRam ---
nv=0; objfields={}
vtxt=(HERE/"vars.toml").read_text(encoding="utf-8")
for b in parse_blocks(vtxt):
    if "offset" in b:                      # object-record field template
        objfields[int(b["offset"],16)]=b; continue
    if "addr" not in b or "name" not in b: continue
    a=int(b["addr"],16)
    cmt=f"[{b.get('role','')}] {flat(b.get('why',''))}"
    lines.append(Symbol(*locate(CART, "ram", a), b['name'], cmt)); nv+=1
# --- object-record fields -> $0400 base object (object 0) ---
no=0
for off,b in sorted(objfields.items()):
    a=0x0400+off
    cmt=f"obj record +{off:X} [{b.get('conf','')}] {flat(b.get('why',''),100)}"
    lines.append(Symbol(*locate(CART, "ram", a), f"obj0_{b['name']}", cmt)); no+=1

out=ROM.with_suffix(".mlb")
problems=write_mlb(lines, out)
print(f"wrote {out.name}: {nf} functions (NesPrgRom), {nv} variables, {no} obj-record fields")
print(f"total {len(lines)-len(problems)} labels")
for p in problems: print("  dropped:", p)
