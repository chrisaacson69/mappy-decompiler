"""code_map.py - Mappy's view of emu_harness's shared 6502 descent (emu-harness MIGRATION.md row B).

One place for what static_expand, jump_tables, stored_pointers and pointer_tables each carried a
copy of: NROM-128 (the 16K shows at $8000 and $C000), BRK ends a path (here it is data, never a
call), and bytes already proven to be table DATA stop a walk.
"""
from pathlib import Path

from emu_harness.cpu.m6502.descent import Window, descend

HERE = Path(__file__).parent
PRG = (HERE / "Mappy (Japan).nes").read_bytes()[16:16 + 0x4000]
WIN = Window(PRG, 0xC000, mirrors=(0x8000,))


def reach(seeds, is_data, code):
    """-> (routines, instruction starts), canonical $C000-$FFFF addresses. Routines are the seeds
    plus every JSR / JMP target reached; every reached byte is marked in the `code` bitmap."""
    seeds = set(seeds)
    d = descend(WIN, seeds, data={0xC000 + n for n in range(0x4000) if is_data[n]}, stop_brk=True)
    for a in d.starts | d.operands:
        code[a - 0xC000] = 1
    jumped = {t for f in d.flows.values() for t in f.jumps.values() if t in WIN}
    return {WIN.canon(a) for a in seeds | jumped if a in WIN} | d.entries, d.starts
