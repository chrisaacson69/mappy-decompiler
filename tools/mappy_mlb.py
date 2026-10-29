#!/usr/bin/env python3
"""
mappy_mlb.py - project labels.toml + vars.toml onto a Mesen 2 .mlb label file.

Reads Mappy's own registry schema ([[...]] blocks); locating and writing are emu-harness's
(machines.nes.memory.locate, backends.mesen.labels), so the file is in Mesen's own export format.
Mappy is NROM-128 (16K mirrored); the cartridge facts come from the ROM header.
Object-record fields are written onto the $0400 base object (object 0) as the record template.
Output: "Mappy (Japan).mlb" at the repo root (committed), and a copy beside the ROM in the ROM store,
where Mesen auto-loads it by basename.
"""
import re
import tomllib
from pathlib import Path

from code_map import symbols
from emu_harness.backends.mesen.labels import write_mlb  # pip install -e ../emu-harness
from emu_harness.core.symbols import Symbol
from emu_harness.machines.nes.memory import Cart, locate

from paths import ROM, MLB, VARS
CART = Cart.from_ines(ROM)

def flat(s, n=140):
    s = re.sub(r'\s+', ' ', s or '').strip()
    return s[:n]

lines=[]
# --- functions -> NesPrgRom ---
nf=0
for b in symbols("label"):
    a=int(b["addr"],16)
    if not (0xC000<=a<=0xFFFF): continue
    cmt=f"[{b.get('conf','')}] {flat(b.get('why',''))}"
    lines.append(Symbol(*locate(CART, "prg.bank0", a), b['name'], cmt)); nf+=1
# --- variables -> NesInternalRam / NesSaveRam ---
nv=0
vdoc=tomllib.loads(VARS.read_text(encoding="utf-8"))
for b in vdoc["var"]:
    a=int(b["addr"],16)
    cmt=f"[{b.get('role','')}] {flat(b.get('why',''))}"
    lines.append(Symbol(*locate(CART, "ram", a), b['name'], cmt)); nv+=1
# --- object-record fields -> the record at $0400 (slot 0, and the base every $04xx,x indexes) ---
no=0
for b in sorted(vdoc.get("obj_field", []), key=lambda f: int(f["offset"],16)):
    off=int(b["offset"],16)
    cmt=f"obj record +{off:X} [{b.get('conf','')}] {flat(b.get('why',''),100)}"
    lines.append(Symbol(*locate(CART, "ram", 0x0400+off), b['name'], cmt)); no+=1

out=MLB
problems=write_mlb(lines, out)
print(f"wrote {out.name}: {nf} functions (NesPrgRom), {nv} variables, {no} obj-record fields")
if ROM.parent.resolve() != out.parent.resolve() and ROM.exists():
    import shutil                                   # Mesen 2 auto-loads a .mlb beside the ROM it opens
    shutil.copyfile(out, ROM.with_suffix(".mlb"))
    print(f"copied -> {ROM.with_suffix('.mlb')} (beside the ROM, for Mesen)")
print(f"total {len(lines)-len(problems)} labels")
for p in problems: print("  dropped:", p)
