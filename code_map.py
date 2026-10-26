"""code_map.py - Mappy's view of emu_harness's native-RE passes (emu-harness MIGRATION.md rows B, R).

One place for what static_expand, jump_tables, stored_pointers and pointer_tables each carried a
copy of: NROM-128 (the 16K shows at $8000 and $C000), BRK ends a path (here it is data, never a
call), and bytes already proven to be table DATA stop a walk.

Word tables live in two files, one line each as `$site base entry...`: jump_tables.txt holds the
dispatch tables (entries are code; jump_tables.py writes it) and data_ptr_tables.txt the hand-kept
pointer tables whose entries are data blobs (the level draw-command tables, 673a53d; no generator
writes it). `table_lines` reads both, so a regenerated jump_tables.txt can no longer drop them.
"""
import tomllib
from pathlib import Path

from emu_harness.cpu.m6502.descent import Window
from emu_harness.passes.native import NativeMap

HERE = Path(__file__).parent
PRG = (HERE / "Mappy (Japan).nes").read_bytes()[16:16 + 0x4000]
WIN = Window(PRG, 0xC000, mirrors=(0x8000,))
# jump_table_dispatch_via_index ($F49F): pla/pla the caller's return address, read the word at
# 2*A+1 past it, jmp ($00F6). A JSR to it never returns, and its word table sits after the call.
INLINE_DISPATCH = {0xF49F}


def symbols(kind):
    """The [[label]] (labels.toml) or [[var]] (vars.toml) entries as dicts, read with tomllib: the one
    reader every generator shares (both files are valid TOML since 2026-10-26)."""
    return tomllib.loads((HERE / f"{kind}s.toml").read_text(encoding="utf-8"))[kind]


def label_names(data=True):
    """{address: name} for every label; data=False leaves out kind = "data" labels (they own no code)."""
    return {int(e["addr"], 16): e["name"] for e in symbols("label") if data or e.get("kind") != "data"}


def var_names():
    """{address: name} for every variable, with the object-record field template ([[obj_field]]) projected
    onto the record at $0400: absolute $0400-$040F is slot 0 and the base every $04xx,x access indexes."""
    doc = tomllib.loads((HERE / "vars.toml").read_text(encoding="utf-8"))
    out = {0x400 + int(f["offset"], 16): f["name"] for f in doc.get("obj_field", [])}
    out.update({int(e["addr"], 16): e["name"] for e in doc["var"]})
    return out


def reach(seeds, is_data, code):
    """-> (routines, instruction starts), canonical $C000-$FFFF addresses. Routines are the seeds
    plus every JSR / JMP target reached; every reached byte is marked in the `code` bitmap."""
    return NativeMap(WIN, code, is_data, noreturn=INLINE_DISPATCH).reach(seeds)


def instruction_starts():
    """bytearray over PRG, 1 at each instruction start of discover's final walk (the
    stored_pointers.py fixpoint: routines_full.txt + the vectors, tables as data). The one
    answer to "is this byte an instruction?" for the passes that read code (var_xref, rom_data)."""
    m = NativeMap(WIN, noreturn=INLINE_DISPATCH)
    for line in table_lines():
        p = line.split(); m.mark_data(int(p[1], 16), 2 * (len(p) - 2))
    seeds = {0xC031, 0xC2EF, 0xC304} | {int(l.strip()[1:], 16) for l in open(HERE / "routines_full.txt")}
    out = bytearray(0x4000)
    for a in m.reach(seeds)[1]:
        out[m.off(a)] = 1
    return out


def table_lines(data=True):
    """The lines of jump_tables.txt, then (with `data`) data_ptr_tables.txt."""
    for name in ("jump_tables.txt",) + (("data_ptr_tables.txt",) if data else ()):
        yield from (l for l in (HERE / name).read_text().splitlines() if l.strip())
