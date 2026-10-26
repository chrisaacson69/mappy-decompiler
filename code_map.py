"""code_map.py - Mappy's view of emu_harness's native-RE passes (emu-harness MIGRATION.md rows B, R).

One place for what static_expand, jump_tables, stored_pointers and pointer_tables each carried a
copy of: NROM-128 (the 16K shows at $8000 and $C000), BRK ends a path (here it is data, never a
call), and bytes already proven to be table DATA stop a walk.

Word tables live in two files, one line each as `$site base entry...`: jump_tables.txt holds the
dispatch tables (entries are code; jump_tables.py writes it) and data_ptr_tables.txt the hand-kept
pointer tables whose entries are data blobs (the level draw-command tables, 673a53d; no generator
writes it). `table_lines` reads both, so a regenerated jump_tables.txt can no longer drop them.
"""
from pathlib import Path

from emu_harness.cpu.m6502.descent import Window
from emu_harness.passes.native import NativeMap

HERE = Path(__file__).parent
PRG = (HERE / "Mappy (Japan).nes").read_bytes()[16:16 + 0x4000]
WIN = Window(PRG, 0xC000, mirrors=(0x8000,))
# jump_table_dispatch_via_index ($F49F): pla/pla the caller's return address, read the word at
# 2*A+1 past it, jmp ($00F6). A JSR to it never returns, and its word table sits after the call.
INLINE_DISPATCH = {0xF49F}


def reach(seeds, is_data, code):
    """-> (routines, instruction starts), canonical $C000-$FFFF addresses. Routines are the seeds
    plus every JSR / JMP target reached; every reached byte is marked in the `code` bitmap."""
    return NativeMap(WIN, code, is_data, noreturn=INLINE_DISPATCH).reach(seeds)


def table_lines(data=True):
    """The lines of jump_tables.txt, then (with `data`) data_ptr_tables.txt."""
    for name in ("jump_tables.txt",) + (("data_ptr_tables.txt",) if data else ()):
        yield from (l for l in (HERE / name).read_text().splitlines() if l.strip())
