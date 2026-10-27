#!/usr/bin/env python3
"""
asm_gen.py - emit a labeled disassembly (mappy_labeled.asm) from our symbol tables.

Drives off the coverage map (code vs data) + labels.toml (function names) + vars.toml (variable
names) + jump_tables.txt (the 6 dispatch tables). Per line:
   addr: rawbytes   mnemonic  <operands substituted to names>     ; original operand
Function entries get `name:` anchors; intra-routine branch/jmp targets get `@addr:` locals;
jump-table bytes emit as `.word handler_name`; uncovered bytes emit as `.byte` data.
"""
import json, re, sys, bisect
from pathlib import Path
from code_map import table_lines, label_names, var_names, symbols   # tables; labels.toml / vars.toml via tomllib
import tomllib
from emu_harness.cpu.m6502 import disasm as disasm6502   # the shared 6502 tables (emu-harness rows B / A3)
from emu_harness.cpu.m6502.cpu import NMI_VECTOR, RESET_VECTOR, IRQ_VECTOR
OPS, MODE_LEN, fmt = disasm6502.OPS, disasm6502.MODE_LEN, disasm6502.fmt_operand
IMP,ACC,IMM,ZP,ZPX,ZPY,ABS,ABX,ABY,IND,IZX,IZY,REL = range(13)

HERE=Path(__file__).parent
PRG=(HERE/"Mappy (Japan).nes").read_bytes()[16:16+0x4000]
def norm(a): return a&0x3FFF
def cpu(a):  return 0xC000+norm(a)

# names
FUNC=label_names()
VAR=var_names()
# listing_art.json (render_assets.py --art): ASCII art of each picture / draw handler's first pose, and
# the decoded string of each text blob, printed as comments under its label
ART=json.loads((HERE/"listing_art.json").read_text(encoding="utf-8")) if (HERE/"listing_art.json").exists() else {}


def clean(why):
    """A symbol's why, as a reader's description: the provenance prefix ('Data walk 2026-10-26: ') and the
    rename history (' Was ...', ' Kept (...', ' Earlier note: ...') left out."""
    # 'Data walk 2026-10-26: ', 'Variables round 2 (2026-10-26): ', 'Assets 2026-10-27 (render_assets.py ...): '
    why = re.sub(r'^[^:]{0,90}?20\d\d-\d\d-\d\d\)?(?: \([^)]*\))?: ', '', why or '')
    return re.split(r" (?:Was '|Kept \(name checked|Earlier note:)", why)[0].strip()


def wrap(text, width=96):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if cur and len(cur) + 1 + len(w) > width:
            lines.append(cur); cur = w
        else:
            cur = f"{cur} {w}" if cur else w
    return lines + ([cur] if cur else [])


# data labels: their description is the layout comment printed above the art
DESC={int(e["addr"],16): clean(e.get("why","")) for e in symbols("label") if e.get("kind")=="data"}

# the RAM structures, for the header: (title, base, stride, count, field source); every field's name and
# meaning comes from vars.toml (the record's from its [[obj_field]] template), so the header cannot drift
STRUCTS=[
    ("object records: slot 0 Mappy, 1 the goal balloon / the coin, 2 Goro, 3-8 Meowkies", 0x0400, 16, "9", "obj_field"),
    ("trampolines", 0x0200, 8, "trampoline_table_len / 8", None),
    ("items (normal rounds) / balloons (bonus rounds)", 0x0260, 8, "item_table_len / 8", None),
    ("doors", 0x02B0, 8, "door_table_len / 8", None),
    ("door waves", 0x04A0, 8, "4", None),
    ("floor traps (rounds 12-14)", 0x0090, 8, "2", None),
    ("stage parameters (load_stage_params, from tbl_stage_params)", 0x0063, 6, "1", None),
    ("round timer", 0x0060, 3, "1", None),
    ("OAM shadow (one sprite per entry)", 0x0700, 4, "64", None),
]


def struct_header():
    vdoc=tomllib.loads((HERE/"vars.toml").read_text(encoding="utf-8"))
    vars_by={int(e["addr"],16): e for e in vdoc["var"]}
    tmpl={int(f["offset"],16): f for f in vdoc.get("obj_field",[])}
    out=["; ---- RAM structures (generated from vars.toml: each field's name and meaning) ----"]
    for title, base, stride, count, src in STRUCTS:
        out.append(f";")
        out.append(f"; {title}: ${base:04X}, {stride} bytes each, x {count}")
        for off in range(stride):
            e = tmpl.get(off) if src == "obj_field" else vars_by.get(base + off)
            if e is None:
                continue
            first = re.split(r"(?<=[.;])\s", clean(e.get("why","")), maxsplit=1)[0]
            first = re.sub(r"^(?:record|trampoline|item|bonus target|balloon|door|door wave|slot \d) \+\w+:? ?", "", first)
            first = "" if first.strip(" .") == "" else first
            out.append(f";   +{off:X}  {e['name']:24s} {first[:84]}".rstrip())
    return out
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

entries=sorted(set(FUNC)|set(VECTORS.values())|{0xC000})   # $C000: the bytes before the first routine are emitted too
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
out += struct_header()
out.append("")
for e in entries:
    nm=FUNC.get(e, {0xC031:"reset_cold_boot_init",0xC2EF:"nmi_sound_tick",0xC304:"irq_rti_stub"}.get(e,f"L_{e:04X}"))
    out.append(f"\n{nm}:")
    for line in wrap(DESC.get(e, "")):                # a data label's layout / meaning
        out.append(f"    ; {line}")
    for line in ART.get(f"{e:04X}", []):              # render_assets.py --art: the picture, pose or text
        out.append(f"    ;   {line}".rstrip())
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
