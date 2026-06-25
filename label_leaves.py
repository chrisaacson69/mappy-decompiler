#!/usr/bin/env python3
"""
label_leaves.py - Phase B step 1: fingerprint the call-graph LEAVES for grounded naming.

A leaf = a routine that calls nothing (no JSR/JMP-abs/dispatch edge out). Leaves are the easy
base of the bottom-up labeling: their behavior is self-contained. For each we emit a deterministic
SIGNATURE (hardware regs touched, hot zero-page, control shape, size, #callers) + the disassembly.
We name from THAT -- never from the repo's labels (the repo stays an after-the-fact diff).

Hardware decoder (the NES register map is the spec/oracle):
  $2000-$2007 PPU | $4014 OAMDMA | $4000-$4013/$4015 APU | $4016-$4017 controller
"""
import sys, bisect
from pathlib import Path
sys.path.insert(0, r"C:\Users\Chris.Isaacson\koei-nes\tools")
import disasm6502
OPS, MODE_LEN, fmt = disasm6502.OPS, disasm6502.MODE_LEN, disasm6502.fmt_operand

HERE = Path(__file__).parent
PRG = (Path("Mappy (Japan).nes").read_bytes())[16:16+0x4000]
def norm(a): return a & 0x3FFF
def cpu(a):  return 0xC000 + norm(a)
def inc(a):  return 0xC000 <= a <= 0xFFFF or 0x8000 <= a <= 0xBFFF

entries = sorted({0xC031,0xC2EF,0xC304} | {int(l.strip()[1:],16) for l in open(HERE/"routines_full.txt")})
ent = set(entries)
tables = {}
for line in open(HERE/"jump_tables.txt"):
    p=line.split(); tables[int(p[0][1:],16)]=(int(p[1],16),[int(x,16) for x in p[2:]])
is_data=bytearray(0x4000)
for site,(base,e) in tables.items():
    for k in range(len(e)): is_data[norm(base+2*k)]=is_data[norm(base+2*k+1)]=1
def owner(a):
    a=cpu(a); i=bisect.bisect_right(entries,a)-1; return entries[i]

# edges (direct + dispatch) -> callees & callers
edges={e:set() for e in entries}
for idx,e in enumerate(entries):
    end=entries[idx+1] if idx+1<len(entries) else 0x10000; pc=e
    while pc<end:
        if is_data[norm(pc)]: pc+=1; continue
        op=PRG[norm(pc)]
        if op not in OPS: pc+=1; continue
        il=1+MODE_LEN.get(OPS[op][1],0)
        if op in (0x20,0x4C):
            t=PRG[norm(pc+1)]|(PRG[norm(pc+2)]<<8)
            if t in ent and t!=e: edges[e].add(t)
        pc+=il
for site,(base,hs) in tables.items():
    o=owner(site)
    for h in hs:
        if h in ent and h!=o: edges[o].add(h)
callers={e:set() for e in entries}
for a,ts in edges.items():
    for t in ts: callers[t].add(a)
leaves=[e for e in entries if not edges[e]]

def hwname(a):
    if a==0x4014: return "OAMDMA"
    if a==0x4016 or a==0x4017: return "JOYPAD"
    if 0x2000<=a<=0x2007: return "PPU:"+{0:"CTRL",1:"MASK",2:"STATUS",3:"OAMADDR",4:"OAMDATA",5:"SCROLL",6:"ADDR",7:"DATA"}[a-0x2000]
    if a==0x4015: return "APU:STATUS"
    if 0x4000<=a<=0x4013: return "APU:$%04X"%a
    return None

def disasm_routine(e):
    end=entries[entries.index(e)+1] if entries.index(e)+1<len(entries) else 0x10000
    out=[]; pc=cpu(e); hw=set(); zp=set(); ram=set(); has_loop=False; ninstr=0
    while pc<min(end,0x10000):
        n=norm(pc)
        if is_data[n]:
            out.append((cpu(pc), f".db ${PRG[n]:02X}")); pc+=1; continue
        op=PRG[n]
        if op not in OPS: out.append((cpu(pc),f".db ${op:02X}")); pc+=1; continue
        mn,mode=OPS[op]; il=1+MODE_LEN.get(mode,0)
        lo=PRG[norm(pc+1)] if il>1 else 0; hi=PRG[norm(pc+2)] if il>2 else 0
        operand=fmt(mode,lo,hi,cpu(pc),il)
        out.append((cpu(pc), f"{mn} {operand}".strip()))
        ninstr+=1
        # feature extraction
        if mode in (6,7,8):  # ABS/ABX/ABY
            a=(hi<<8)|lo
            if hwname(a): hw.add(hwname(a))
            elif a<0x800: ram.add(a)
        if mode in (3,4,5):  # ZP/ZPX/ZPY
            zp.add(lo)
        if op in (0x10,0x30,0x50,0x70,0x90,0xB0,0xD0,0xF0):
            off=lo-0x100 if lo>=0x80 else lo
            if off<0: has_loop=True
        pc+=il
        # decode the full routine span [entry, next_entry); don't stop at the first rts/jmp
        # (routines have early returns / mid-body jumps). is_data bytes are skipped above.
    return out, dict(hw=sorted(hw), zp=sorted(f"${z:02X}" for z in sorted(zp)),
                     ram=sorted(f"${r:04X}" for r in sorted(ram)),
                     loop=has_loop, ninstr=ninstr, nbytes=cpu(pc)-cpu(e))

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
