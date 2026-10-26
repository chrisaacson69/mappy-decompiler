#!/usr/bin/env python3
"""
obj_record.py - the DATA pass: recover the 16-byte object-record field layout.

The record is touched two equivalent ways that name the SAME field offsets:
  * indirect:  LDY #off ; LDA/STA (objptr),y    -> field `off` of the current object
  * absolute:  LDA/STA $0400+off,x  (x = obj*$10) -> field `off` (low nibble)
By unioning ALL such accesses per offset across every NAMED routine, each field is defined by
how the whole engine uses it at once (resolving the per-field fuzziness of naming addresses solo).
The census itself is emu_harness.passes.native.field_census (row R).

objptr slots = the zp pointers vars.toml called obj*record_ptr. CLI:
  obj_record.py            -> summary: per-offset routine/access counts
  obj_record.py field N    -> full profile of field N (every routine + context) for an agent
  obj_record.py fields     -> JSON ["00".."0F"]
"""
import re, sys, json
from pathlib import Path

from emu_harness.passes.native import NativeMap, field_census
from code_map import HERE, WIN

M=NativeMap(WIN)
def norm(a): return M.off(a)
def cpu(a):  return M.canon(a)

LABELS={}; cur=None
for l in (HERE/"labels.toml").read_text(encoding="utf-8").splitlines():
    m=re.search(r'addr\s*=\s*"([0-9A-Fa-f]{4})"',l)
    if m: cur=int(m.group(1),16)
    m=re.search(r'name\s*=\s*"([^"]+)"',l)
    if m and cur is not None: LABELS[cur]=m.group(1); cur=None
entries=sorted(set(LABELS)|{0xC031,0xC2EF,0xC304})
for line in open(HERE/"jump_tables.txt"):
    p=line.split(); M.mark_data(int(p[1],16), 2*(len(p)-2))

# object-record pointer low bytes (from vars.toml: names containing obj + record + ptr, not _hi)
objptr=set()
for l in (HERE/"vars.toml").read_text(encoding="utf-8").splitlines():
    m=re.search(r'addr = "([0-9A-Fa-f]{4})"',l)
    if m: va=int(m.group(1),16)
    m=re.search(r'name = "([^"]+)"',l)
    if m and re.search(r'obj.*record.*ptr',m.group(1)) and not m.group(1).endswith("_hi") and va<0x100:
        objptr.add(va)
objptr|={0x1E,0x1C,0x26,0x36,0x31}   # belt-and-suspenders

fields=field_census(M, entries, pointers=objptr, table=(0x400, 0x48F), size=16)

if __name__=="__main__":
    args=sys.argv[1:]
    if args and args[0]=="fields":
        print(json.dumps([f"{i:02X}" for i in range(16)])); sys.exit()
    if args and args[0]=="field":
        off=int(args[1],0); routes=fields[off]
        print(f"; OBJECT-RECORD FIELD +{off} (offset ${off:X})  touched by {len(routes)} routines")
        print(f"; (accessed as (obj_record_ptr),y with Y=#${off:02X}  and as $04{off:X},x)")
        print("; kinds: w=write r=read m=read-modify-write\n")
        for e in sorted(routes):
            rr=routes[e]
            print(f"  {LABELS.get(e,f'sub_{e:04X}'):44s} [{','.join(sorted(rr['kinds']))}]")
            for ln in rr["lines"][:3]: print(f"        {ln}")
        sys.exit()
    print(f"object-record pointers: {sorted('$%02X'%p for p in objptr)}\n")
    print("offset  #rtns  W?  sample routines")
    for i in range(16):
        routes=fields[i]
        names=sorted({LABELS.get(e,'') for e in routes})
        w="W" if any(k[0]=="w" for r in routes.values() for k in r["kinds"]) else " "
        print(f"  +{i:X}   {len(routes):4d}   {w}   {', '.join(n for n in names if n)[:64]}")
