#!/usr/bin/env python3
"""
mappy_mlb.py - project labels.toml + vars.toml onto a Mesen 2 .mlb label file.

Format reused verbatim from na1-decompiler/tools/mesen-labels.py (validated against a working
Mesen 2 load):  Type:Address:Label:Comment   (Mesen splits on the first 3 colons).
  NesPrgRom     PRG offset = cpu & 0x3FFF   (Mappy = NROM-128, 16K mapped at $C000-$FFFF)
  NesInternalRam  $0000-$07FF, address-relative
  NesSaveRam      $6000-$7FFF (none here)
Object-record fields are written onto the $0400 base object (object 0) as the record template.
Output: "Mappy (Japan).mlb" beside the ROM, so Mesen auto-loads it by basename.
"""
import re
from pathlib import Path
HERE = Path(__file__).parent
ROM = HERE / "Mappy (Japan).nes"

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
    off=a & 0x3FFF
    cmt=f"[{b.get('conf','')}] {flat(b.get('why',''))}"
    lines.append(f"NesPrgRom:{off:X}:{b['name']}:{cmt}"); nf+=1
# --- variables -> NesInternalRam / NesSaveRam ---
nv=0; objfields={}
vtxt=(HERE/"vars.toml").read_text(encoding="utf-8")
for b in parse_blocks(vtxt):
    if "offset" in b:                      # object-record field template
        objfields[int(b["offset"],16)]=b; continue
    if "addr" not in b or "name" not in b: continue
    a=int(b["addr"],16)
    cmt=f"[{b.get('role','')}] {flat(b.get('why',''))}"
    if a<0x0800: t=f"NesInternalRam:{a:X}"
    elif 0x6000<=a<=0x7FFF: t=f"NesSaveRam:{a-0x6000:X}"
    else: t=f"NesMemory:{a:X}"
    lines.append(f"{t}:{b['name']}:{cmt}"); nv+=1
# --- object-record fields -> $0400 base object (object 0) ---
no=0
for off,b in sorted(objfields.items()):
    a=0x0400+off
    cmt=f"obj record +{off:X} [{b.get('conf','')}] {flat(b.get('why',''),100)}"
    lines.append(f"NesInternalRam:{a:X}:obj0_{b['name']}:{cmt}"); no+=1

out=ROM.with_suffix(".mlb")
out.write_text("\n".join(lines)+"\n", encoding="utf-8")
print(f"wrote {out.name}: {nf} functions (NesPrgRom), {nv} variables, {no} obj-record fields")
print(f"total {len(lines)} labels")
print("sample:")
for l in lines[:3]+lines[nf:nf+3]: print("  "+l)
