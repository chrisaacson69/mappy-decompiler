#!/usr/bin/env python3
"""
asm_gen.py - emit a labeled disassembly (mappy_labeled.asm) from our symbol tables.

Drives off the coverage map (code vs data) + labels.toml (function names) + vars.toml (variable
names) + jump_tables.txt (the 6 dispatch tables). Per line:
   addr: rawbytes   mnemonic  <operands substituted to names>     ; original operand
Function entries get `name:` anchors; intra-routine branch/jmp targets get `@addr:` locals;
jump-table bytes emit as `.word handler_name`; uncovered bytes emit as `.byte` data.
"""
import re, sys, bisect
from pathlib import Path
from code_map import table_lines   # jump_tables.txt + data_ptr_tables.txt
from emu_harness.cpu.m6502 import disasm as disasm6502   # the shared 6502 tables (emu-harness rows B / A3)
from emu_harness.cpu.m6502.cpu import NMI_VECTOR, RESET_VECTOR, IRQ_VECTOR
OPS, MODE_LEN, fmt = disasm6502.OPS, disasm6502.MODE_LEN, disasm6502.fmt_operand
IMP,ACC,IMM,ZP,ZPX,ZPY,ABS,ABX,ABY,IND,IZX,IZY,REL = range(13)

HERE=Path(__file__).parent
PRG=(HERE/"Mappy (Japan).nes").read_bytes()[16:16+0x4000]
def norm(a): return a&0x3FFF
def cpu(a):  return 0xC000+norm(a)

# names
FUNC={}; cur=None
for l in (HERE/"labels.toml").read_text(encoding="utf-8").splitlines():
    m=re.search(r'addr\s*=\s*"([0-9A-Fa-f]{4})"',l)
    if m: cur=int(m.group(1),16)
    m=re.search(r'name\s*=\s*"([^"]+)"',l)
    if m and cur is not None: FUNC[cur]=m.group(1); cur=None
VAR={}; cur=None
for l in (HERE/"vars.toml").read_text(encoding="utf-8").splitlines():
    m=re.search(r'addr\s*=\s*"([0-9A-Fa-f]{4})"',l)
    if m: cur=int(m.group(1),16)
    m=re.search(r'name\s*=\s*"([^"]+)"',l)
    if m and cur is not None and cur not in VAR: VAR[cur]=m.group(1); cur=None
# hardware register names
HW={0x2000:"PPUCTRL",0x2001:"PPUMASK",0x2002:"PPUSTATUS",0x2003:"OAMADDR",0x2004:"OAMDATA",
    0x2005:"PPUSCROLL",0x2006:"PPUADDR",0x2007:"PPUDATA",0x4014:"OAMDMA",0x4015:"APUSTATUS",
    0x4016:"JOY1",0x4017:"JOY2"}
for a in range(0x4000,0x4014): HW[a]=f"APU_{a:04X}"

# jump tables: data ranges -> {addr: handler_name}
TABLE={}; is_data=bytearray(0x4000)
for line in table_lines():
    p=line.split(); base=int(p[1],16); ents=[int(x,16) for x in p[2:]]
    for k,t in enumerate(ents):
        a=base+2*k
        TABLE[a]=FUNC.get(t,f"L_{t:04X}"); is_data[norm(a)]=is_data[norm(a+1)]=1
# the 6502's own vector words: the CPU reads NMI / RESET / IRQ entry points from them
VECTORS={v:PRG[norm(v)]|PRG[norm(v+1)]<<8 for v in (NMI_VECTOR,RESET_VECTOR,IRQ_VECTOR)}
for v,t in VECTORS.items():
    TABLE[v]=FUNC.get(t,f"L_{t:04X}"); is_data[norm(v)]=is_data[norm(v+1)]=1

entries=sorted(set(FUNC)|set(VECTORS.values()))
end_of={e:(entries[i+1] if i+1<len(entries) else 0x10000) for i,e in enumerate(entries)}

# coverage (code vs data)
cov=(HERE/"coverage_full2.bin").read_bytes() if (HERE/"coverage_full2.bin").exists() else (HERE/"coverage_full.bin").read_bytes()
def is_code(a): return 0xC000<=a<=0xFFFF and cov[norm(a)] and not is_data[norm(a)]

def opname(a):                       # absolute/zp operand -> symbol
    if a in HW: return HW[a]
    if a<0x800 and a in VAR: return VAR[a]
    if 0xC000<=a<=0xFFFF and a in FUNC: return FUNC[a]
    return None

# --- pass 1: collect intra-routine branch/jmp local-label targets ---
locals_=set()
for e in entries:
    pc=cpu(e)
    while pc<cpu(end_of[e]):
        if not is_code(pc): pc+=1; continue
        op=PRG[norm(pc)]; mn,mode=OPS.get(op,("?",IMP)); il=1+MODE_LEN.get(mode,0)
        if mode==REL:
            off=PRG[norm(pc+1)]; off-=0x100 if off>=0x80 else 0
            t=(pc+2+off)&0xFFFF
            if t not in FUNC: locals_.add(t)
        elif op==0x4C:
            t=PRG[norm(pc+1)]|(PRG[norm(pc+2)]<<8)
            if 0xC000<=t<=0xFFFF and t not in FUNC: locals_.add(t)
        pc+=il

def sym(a):
    if a in FUNC: return FUNC[a]
    if a in locals_: return f"@{a:04X}"
    return None

# --- pass 2: emit ---
out=[]
out.append("; Mappy (Japan) PRG $C000-$FFFF  --  labeled disassembly, generated from")
out.append("; labels.toml + vars.toml + jump_tables.txt (from-scratch RE; no external labels).\n")
for e in entries:
    nm=FUNC.get(e, {0xC031:"reset_cold_boot_init",0xC2EF:"nmi_sound_tick",0xC304:"irq_rti_stub"}.get(e,f"L_{e:04X}"))
    out.append(f"\n{nm}:")
    pc=cpu(e); endpc=end_of[e] if end_of[e]>0xFFFF else cpu(end_of[e])  # last entry: 0x10000 must not cpu()-wrap to $C000
    while pc<endpc:
        a=pc
        if a in locals_ and a!=e: out.append(f"@{a:04X}:")
        if a in TABLE:
            out.append(f"    {a:04X}:            .word {TABLE[a]}"); pc+=2; continue
        if not is_code(a):
            b=PRG[norm(a)]; out.append(f"    {a:04X}: {b:02X}          .byte ${b:02X}"); pc+=1; continue
        op=PRG[norm(a)]
        if op not in OPS:
            out.append(f"    {a:04X}: {op:02X}          .byte ${op:02X}"); pc+=1; continue
        mn,mode=OPS[op]; il=1+MODE_LEN.get(mode,0)
        lo=PRG[norm(a+1)] if il>1 else 0; hi=PRG[norm(a+2)] if il>2 else 0
        raw=" ".join(f"{PRG[norm(a+k)]:02X}" for k in range(il))
        operand=fmt(mode,lo,hi,a,il); comment=""
        if mode==REL:
            t=(a+2+(lo-0x100 if lo>=0x80 else lo))&0xFFFF; s=sym(t)
            if s: operand=s; comment=f"   ; ${t:04X}"
        elif mode in (ABS,ABX,ABY,IND) and op in (0x20,0x4C,0x6C) or mode in (ABS,ABX,ABY):
            tgt=(hi<<8)|lo; s=opname(tgt)
            if s:
                suff={ABX:",x",ABY:",y"}.get(mode,"")
                operand=(f"({s})" if mode==IND else s+suff); comment=f"   ; ${tgt:04X}"
        elif mode in (ZP,ZPX,ZPY):
            s=VAR.get(lo)
            if s:
                suff={ZPX:",x",ZPY:",y"}.get(mode,"")
                operand=s+suff; comment=f"   ; ${lo:02X}"
        elif mode in (IZX,IZY):
            s=VAR.get(lo)
            if s: operand=(f"({s},x)" if mode==IZX else f"({s}),y"); comment=f"   ; ${lo:02X}"
        out.append(f"    {a:04X}: {raw:11s} {mn} {operand}{comment}".rstrip())
        pc+=il

(HERE/"mappy_labeled.asm").write_text("\n".join(out)+"\n", encoding="utf-8")
nloc=len(locals_)
print(f"wrote mappy_labeled.asm: {len(entries)} routines, {nloc} local labels, {len(TABLE)} jump-table words")
print(f"  lines: {len(out)}")
