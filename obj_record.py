#!/usr/bin/env python3
"""
obj_record.py - the DATA pass: recover the 16-byte object-record field layout.

The record is touched two equivalent ways that name the SAME field offsets:
  * indirect:  LDY #off ; LDA/STA (objptr),y    -> field `off` of the current object
  * absolute:  LDA/STA $0400+off,x  (x = obj*$10) -> field `off` (low nibble)
By unioning ALL such accesses per offset across every NAMED routine, each field is defined by
how the whole engine uses it at once (resolving the per-field fuzziness of naming addresses solo).

objptr slots = the zp pointers vars.toml called obj*record_ptr. CLI:
  obj_record.py            -> summary: per-offset routine/access counts
  obj_record.py field N    -> full profile of field N (every routine + context) for an agent
  obj_record.py fields     -> JSON ["00".."0F"]
"""
import re, sys, json, bisect
from pathlib import Path
sys.path.insert(0, r"C:\Users\Chris.Isaacson\koei-nes\tools")
import disasm6502
OPS, MODE_LEN, fmt = disasm6502.OPS, disasm6502.MODE_LEN, disasm6502.fmt_operand
IMP,ACC,IMM,ZP,ZPX,ZPY,ABS,ABX,ABY,IND,IZX,IZY,REL = range(13)

HERE=Path(__file__).parent
PRG=(HERE/"Mappy (Japan).nes").read_bytes()[16:16+0x4000]
def norm(a): return a&0x3FFF
def cpu(a):  return 0xC000+norm(a)

LABELS={}; cur=None
for l in (HERE/"labels.toml").read_text(encoding="utf-8").splitlines():
    m=re.search(r'addr\s*=\s*"([0-9A-Fa-f]{4})"',l)
    if m: cur=int(m.group(1),16)
    m=re.search(r'name\s*=\s*"([^"]+)"',l)
    if m and cur is not None: LABELS[cur]=m.group(1); cur=None
entries=sorted(set(LABELS)|{0xC031,0xC2EF,0xC304})
is_data=bytearray(0x4000)
for line in open(HERE/"jump_tables.txt"):
    p=line.split(); base=int(p[1],16)
    for k in range(len(p)-2): is_data[norm(base+2*k)]=is_data[norm(base+2*k+1)]=1
def owner(a): return entries[bisect.bisect_right(entries,cpu(a))-1]

# object-record pointer low bytes (from vars.toml: names containing obj + record + ptr, not _hi)
objptr=set()
for l in (HERE/"vars.toml").read_text(encoding="utf-8").splitlines():
    m=re.search(r'addr = "([0-9A-Fa-f]{4})"',l)
    if m: va=int(m.group(1),16)
    m=re.search(r'name = "([^"]+)"',l)
    if m and re.search(r'obj.*record.*ptr',m.group(1)) and not m.group(1).endswith("_hi") and va<0x100:
        objptr.add(va)
objptr|={0x1E,0x1C,0x26,0x36,0x31}   # belt-and-suspenders

READ={"lda","ldx","ldy","cmp","cpx","cpy","adc","sbc","and","ora","eor","bit"}
WRITE={"sta","stx","sty"}; RMW={"inc","dec","asl","lsr","rol","ror"}
def kind(mn): return "w" if mn in WRITE else ("m" if mn in RMW else "r")

fields={i:{} for i in range(16)}   # offset -> {routine -> {'kinds':set,'lines':[]}}
def rec(off,e,k,line):
    d=fields[off].setdefault(e,{"kinds":set(),"lines":[]})
    d["kinds"].add(k)
    if len(d["lines"])<4: d["lines"].append(line)

for idx,e in enumerate(entries):
    end=cpu(entries[idx+1]) if idx+1<len(entries) else 0x10000
    pc=cpu(e); cur_y=None
    while pc<end:
        n=norm(pc)
        if is_data[n]: pc+=1; continue
        op=PRG[n]
        if op not in OPS: pc+=1; cur_y=None; continue
        mn,mode=OPS[op]; il=1+MODE_LEN.get(mode,0)
        lo=PRG[norm(pc+1)] if il>1 else 0; hi=PRG[norm(pc+2)] if il>2 else 0
        line=f"${cpu(pc):04X}: {mn} {fmt(mode,lo,hi,cpu(pc),il)}".strip()
        # track constant Y
        if mn=="ldy" and mode==IMM: cur_y=lo
        elif mn in ("tay","iny","dey") or (mn=="ldy" and mode!=IMM): cur_y=None
        # indirect (objptr),y with known const Y
        if mode==IZY and lo in objptr and cur_y is not None and cur_y<16:
            rec(cur_y, e, kind(mn), line)
        # absolute object-table field $0400-$048F
        if mode in (ABS,ABX,ABY):
            a=(hi<<8)|lo
            if 0x400<=a<=0x48F: rec(a&0x0F, e, kind(mn), line)
        pc+=il

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
