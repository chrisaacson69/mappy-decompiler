#!/usr/bin/env python3
"""
var_xref.py - cross-reference every RAM/zero-page variable to the NAMED routines that use it.

Now that all 258 functions are labeled, a variable's meaning falls out of *who* touches it and
*how*: reads vs writes vs read-modify-write, whether it's indexed (an array), and whether it's
dereferenced as a 16-bit pointer ((zp),y / (zp,x) -> the zp pair is a pointer; its target is the
data structure). The variable-side twin of the function label-walk.

Modes (disasm6502): ZP/ZPX/ZPY -> zero-page var; ABS/ABX/ABY (<$0800) -> RAM var;
IZX/IZY -> the zp operand is a 16-bit POINTER (lo, lo+1).

CLI:
  var_xref.py            -> summary table of all touched vars (sorted by #distinct routines)
  var_xref.py one 0xADDR -> full profile of one var (every routine + instruction context) for agents
  var_xref.py hot N      -> JSON list of the N most-used unnamed vars (for the naming batch)
"""
import re, sys, json, bisect
from pathlib import Path
sys.path.insert(0, r"C:\Users\Chris.Isaacson\koei-nes\tools")
import disasm6502
OPS, MODE_LEN = disasm6502.OPS, disasm6502.MODE_LEN
fmt = disasm6502.fmt_operand
IMP,ACC,IMM,ZP,ZPX,ZPY,ABS,ABX,ABY,IND,IZX,IZY,REL = range(13)

HERE = Path(__file__).parent
PRG = (HERE / "Mappy (Japan).nes").read_bytes()[16:16+0x4000]
def norm(a): return a & 0x3FFF
def cpu(a):  return 0xC000 + norm(a)

# routine entries + names + per-table data bytes (skip tables)
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
def owner_name(a):
    i=bisect.bisect_right(entries,cpu(a))-1
    return LABELS.get(entries[i],f"sub_{entries[i]:04X}")

READ={"lda","ldx","ldy","cmp","cpx","cpy","adc","sbc","and","ora","eor","bit"}
WRITE={"sta","stx","sty"}
RMW={"inc","dec","asl","lsr","rol","ror"}

# var -> {routine_entry -> {'r','w','m','p','i'} flags + sample lines}
xref={}
def rec(addr, e, kind, line):
    d=xref.setdefault(addr,{})
    rt=d.setdefault(e,{"kinds":set(),"lines":[]})
    rt["kinds"].add(kind)
    if len(rt["lines"])<3: rt["lines"].append(line)

for idx,e in enumerate(entries):
    end=cpu(entries[idx+1]) if idx+1<len(entries) else 0x10000
    pc=cpu(e)
    while pc<end:
        n=norm(pc)
        if is_data[n]: pc+=1; continue
        op=PRG[n]
        if op not in OPS: pc+=1; continue
        mn,mode=OPS[op]; il=1+MODE_LEN.get(mode,0)
        lo=PRG[norm(pc+1)] if il>1 else 0; hi=PRG[norm(pc+2)] if il>2 else 0
        line=f"${cpu(pc):04X}: {mn} {fmt(mode,lo,hi,cpu(pc),il)}".strip()
        kind = "w" if mn in WRITE else ("m" if mn in RMW else ("r" if mn in READ else "?"))
        if mode in (ZP,ZPX,ZPY):
            rec(lo, e, kind+("i" if mode!=ZP else ""), line)
        elif mode in (ABS,ABX,ABY):
            a=(hi<<8)|lo
            if a<0x800: rec(a, e, kind+("i" if mode!=ABS else ""), line)
        elif mode in (IZX,IZY):
            rec(lo, e, "p", line); rec((lo+1)&0xFF, e, "p", line)   # pointer pair
        pc+=il

def summary_flags(routes):
    K=set().union(*[r["kinds"] for r in routes.values()])
    f=""
    f+="P" if any("p" in k for k in K) else " "
    f+="W" if any(k[0]=="w" for k in K) else " "
    f+="R" if any(k[0]=="r" for k in K) else " "
    f+="M" if any(k[0]=="m" for k in K) else " "
    f+="i" if any("i" in k for k in K) else " "
    return f

if __name__=="__main__":
    args=sys.argv[1:]
    if args and args[0]=="one":
        a=int(args[1],0); routes=xref.get(a,{})
        ptr = any("p" in rr["kinds"] for rr in routes.values())
        print(f"; VARIABLE ${a:04X}  ({'zero-page' if a<0x100 else 'RAM'})  touched by {len(routes)} routines"
              f"{'  [used as 16-bit POINTER low byte]' if ptr else ''}")
        print("; flags: P=pointer-deref W=write R=read M=rmw i=indexed(array)")
        # writers first (who SETS it is most telling), then the rest; cap to keep it readable
        wr=[e for e in routes if any(k[0]=="w" for k in routes[e]["kinds"])]
        rest=[e for e in routes if e not in wr]
        shown=(sorted(wr)+sorted(rest))[:28]
        if len(routes)>28: print(f"; (showing 28 of {len(routes)} routines; writers first)")
        print()
        for e in shown:
            rr=routes[e]; ks=",".join(sorted(rr["kinds"]))
            print(f"  {LABELS.get(e,f'sub_{e:04X}'):42s} [{ks}]")
            for ln in rr["lines"][:2]: print(f"        {ln}")
        sys.exit()
    if args and args[0]=="hot":
        N=int(args[1]);
        named=set()  # (none yet — var names live in vars.toml later)
        rows=sorted(xref, key=lambda a:-len(xref[a]))
        print(json.dumps([f"{a:04X}" for a in rows[:N]]))
        sys.exit()
    # default: summary table
    rows=sorted(xref, key=lambda a:-len(xref[a]))
    print(f"{len(xref)} distinct RAM/zp variables touched\n")
    print("addr   flags  #rtns  sample routines")
    for a in rows[:60]:
        routes=xref[a]
        names=sorted({LABELS.get(e,'') for e in routes})
        samp=", ".join(n for n in names if n)[:70]
        print(f"${a:04X}  {summary_flags(routes)}  {len(routes):4d}   {samp}")
