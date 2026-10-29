#!/usr/bin/env python3
"""
rom_data.py - the DATA pass over PRG: run the game's own walkers over every table index, and let
them say which bytes are data and what text they paint.

Grounding: no grammar is re-implemented. Each walker runs headless on emu-harness (cpu.m6502 over
machines.nes.bus.Bus with a PPUPort), as render_level does, and two things are recorded:
  * the PRG bytes it READ that are not code (coverage_full2.bin): the exact extent of the data it
    consumed, its own terminators included;
  * the nametable cells it WROTE, decoded with FONT into text by screen row.
Then every non-code PRG byte is either claimed by a run or reported as unaccounted.

FONT (tile -> character): the CHR atlas (mappy_chr_atlas.png) shows a blank, 0-9, A-Z, '.', '(c)'
at the head of pattern table 0. The offset was checked against the PRG, not the picture alone: with
$0B = 'A' the bytes at $CCDA read ALL RIGHTS RESERVED; with $0A = 'A' they read ZBMM SJHIUT.

CLI:
  rom_data.py          -> per-walker extents and text, then the unaccounted PRG ranges
  rom_data.py --write  -> also writes rom_data.txt (the data phase's evidence)
"""
import sys
from pathlib import Path

from emu_harness.cpu.m6502.cpu import CPU6502
from emu_harness.cpu.m6502.disasm import ABS, ABX, ABY, OPS
from emu_harness.machines.nes.bus import Bus
from emu_harness.machines.nes.ppuport import PPUPort
from code_map import PRG, instruction_starts, table_lines
from paths import DISCOVER, DATA, TRACES, ROM as ROM_FILE

ROM = ROM_FILE.read_bytes()
CODE = (DISCOVER / "coverage_full2.bin").read_bytes()

STARTS = instruction_starts()

FONT = {0x00: " "} | {0x01 + i: str(i) for i in range(10)} | {0x0B + i: chr(65 + i) for i in range(26)} \
       | {0x25: ".", 0x26: "©"}

# (job, walker entry, Y values): the walkers and the index each table allows, from their callers
# (build_stage_screen_layout $CD49 for the three level tables; load_ptr_descriptor_and_scan $CECD
# indexes the 4-byte [ppu addr][text ptr] records at $CF08 by Y = 4*k).
JOBS = [
    ("palhud  $CC15 / tbl $CC41", 0xCC15, range(0, 10, 2)),
    ("frame   $CF69 / tbl $CFA6", 0xCF69, range(0, 12, 2)),
    ("mansion $D126 / tbl $D185", 0xD126, range(0, 14, 2)),
    ("text    $CECD / tbl $CF08", 0xCECD, range(0, 20, 4)),
]


class ReadLog(Bus):
    """Bus that remembers every PRG offset read."""
    def __init__(self, rom, ppu):
        super().__init__(rom, ppu=ppu)
        self.prg_reads = set()

    def read(self, addr):
        addr &= 0xFFFF
        if addr >= 0x8000:
            self.prg_reads.add((addr - 0x8000) & 0x3FFF)
        return super().read(addr)


def run(entry, y):
    """JSR `entry` with Y and run to its RTS. -> (data offsets read, PPUPort)."""
    port = PPUPort()
    bus = ReadLog(ROM, port)
    call(CPU6502(bus), entry, y)
    return {o for o in bus.prg_reads if not CODE[o]}, port


def text(port):
    """Nametable rows the run painted, as (ppu address of the row's first cell, decoded string).
    Only rows with at least three letters: the rest is tile art."""
    out = []
    for page in (0x2000, 0x2400, 0x2800, 0x2C00):
        for row in range(30):
            base = page + 32 * row
            cells = [c for c in range(32) if port.written[base + c]]
            if not cells:
                continue
            s = "".join(FONT.get(port.vram[base + c], "·") if port.written[base + c] else " "
                        for c in range(cells[0], cells[-1] + 1))
            if sum(ch.isalpha() for ch in s) >= 3:
                out.append((base + cells[0], s.rstrip()))
    return out


def demo_reads(frames=4000):
    """Non-code PRG offsets read while the game plays its attract demo from RESET, with NMI each
    frame: trace_codegraph.py's run, on the logging bus. Cached in demo_reads.bin (2+ minutes)."""
    cache = TRACES / "demo_reads.bin"
    if not cache.exists():
        from emu_harness.cpu.m6502.coverage import trace_coverage
        from emu_harness.cpu.m6502.descent import Window
        bus = ReadLog(ROM, None)
        cpu = CPU6502(bus)
        cpu.pc, cpu.sp = bus.read_word(0xFFFC), 0xFD
        bus.prg_reads.clear()
        trace_coverage(cpu, Window(PRG, 0xC000, mirrors=(0x8000,)), ticks=frames, tick_every=12000,
                       max_steps=80_000_000)
        cache.write_bytes(bytes(1 if o in bus.prg_reads else 0 for o in range(0x4000)))
    return {o for o, r in enumerate(cache.read_bytes()) if r and not CODE[o]}


VOICES, SOUND_INIT, SOUND_TICK, TRIGGER = 25, 0xF4B5, 0xF4F1, 0x0600


def sound_reads(frames=4800):
    """{voice: non-code PRG offsets read} with only that voice triggered: the engine's own init
    ($F4B5), the trigger byte $0600+k = 1 (what the game stores at e.g. $C95B), then the per-frame
    entry ($F4F1, called from the main loop and the NMI) `frames` times. Set once: a voice flagged
    in $F885 clears its byte when it starts ($F5B3); the others play while it stays nonzero.
    Cached in sound_reads.bin."""
    cache = TRACES / "sound_reads.bin"
    if not cache.exists():
        out = bytearray()
        for k in range(VOICES):
            bus = ReadLog(ROM, None)
            cpu = CPU6502(bus)
            call(cpu, SOUND_INIT)
            bus.prg_reads.clear()
            bus.ram[TRIGGER + k] = 1
            for _ in range(frames):
                call(cpu, SOUND_TICK)
            out += bytes(1 if o in bus.prg_reads else 0 for o in range(0x4000))
        cache.write_bytes(bytes(out))
    raw = cache.read_bytes()
    return {k: {o for o in range(0x4000) if raw[k * 0x4000 + o] and not CODE[o]} for k in range(VOICES)}


def call(cpu, entry, y=0):
    """JSR `entry` with Y and run to its RTS (sentinel return $FFFF)."""
    cpu.a, cpu.x, cpu.y, cpu.sp = 0, 0, y, 0xFD
    cpu.push_word(0xFFFE)                       # RTS -> $FFFF
    cpu.pc = entry
    cpu.run_until({0xFFFF}, max_steps=2_000_000)


def ranges(offsets):
    """Sorted offsets -> [(cpu start, cpu end inclusive)]."""
    out = []
    for o in sorted(offsets):
        if out and o == out[-1][1] - 0xC000 + 1:
            out[-1][1] += 1
        else:
            out.append([0xC000 + o, 0xC000 + o])
    return [tuple(r) for r in out]


def main(write=False):
    lines, claimed = [], {}
    for job, entry, ys in JOBS:
        lines.append(f"## {job}")
        for y in ys:
            data, port = run(entry, y)
            for o in data:
                claimed.setdefault(o, set()).add(job.split()[0])
            span = " ".join(f"${a:04X}-${b:04X}" for a, b in ranges(data))
            lines.append(f"  Y={y:02X}  {len(data):4d} B  {span}")
            for addr, s in text(port):
                lines.append(f"        ${addr:04X}  |{s}|")
    # known tables: dispatch / data pointer word tables, the round table, the demo script, vectors
    for line in table_lines():
        p = line.split(); base = int(p[1], 16)
        for k in range(2 * (len(p) - 2)):
            claimed.setdefault((base + k) & 0x3FFF, set()).add("table")
    for a, n in ((0xCDBF, 64), (0xFFFA, 6)):          # tbl_round_attributes 16x4; the vectors
        for k in range(n):
            claimed.setdefault((a + k) & 0x3FFF, set()).add("table")
    demo = demo_reads()
    for o in demo:
        claimed.setdefault(o, set()).add("demo")
    lines.append(f"\nattract demo (4,000 frames from RESET): {len(demo):,} data bytes read, "
                 f"{sum(1 for o in demo if claimed[o] == {'demo'}):,} of them by no walker or table")
    lines.append("\n## sound: one voice triggered, 4,800 frames of the engine")
    for k, reads in sound_reads().items():
        for o in reads:
            claimed.setdefault(o, set()).add("sound")
        span = " ".join(f"${a:04X}-${b:04X}" for a, b in ranges(reads))
        lines.append(f"  voice {k:2d} (${TRIGGER + k:04X})  {len(reads):4d} B  {span}")
    noncode = [o for o in range(0x4000) if not CODE[o]]
    loose = [o for o in noncode if o not in claimed]
    # operand references into what is left: the table's first byte is exact, its reader known
    refs, loose_set = {}, set(loose)
    for o in range(0x4000):
        if not STARTS[o]:
            continue
        op = PRG[o]; mode = OPS[op][1] if op in OPS else None
        if mode in (ABS, ABX, ABY):
            t = (PRG[o + 1] | PRG[o + 2] << 8)
            if t >= 0x8000 and (t - 0x8000) & 0x3FFF in loose_set:
                refs.setdefault((t - 0x8000) & 0x3FFF, []).append(0xC000 + o)
    residue, read_by = ranges(loose), {}
    for a, b in residue:
        read_by[a] = sorted({r for t in range(a - 0xC000, b - 0xC000 + 1) for r in refs.get(t, [])})
    referenced = sum(b - a + 1 for a, b in residue if read_by[a])
    lines.append(f"\nnon-code PRG {len(noncode):,} B; claimed by a run or a known table "
                 f"{len(noncode) - len(loose):,} B; unclaimed {len(loose):,} B in {len(residue)} ranges: "
                 f"{referenced:,} B where code reads into the range (abs / abs,X / abs,Y), "
                 f"{len(loose) - referenced:,} B that no operand reaches")
    for a, b in residue:
        who = " ".join(f"${r:04X}" for r in read_by[a][:6]) if read_by[a] else "-"
        lines.append(f"  ${a:04X}-${b:04X}  {b - a + 1:5d} B  read at {who}")
    print("\n".join(lines))
    if write:
        (DATA / "rom_data.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(write="--write" in sys.argv)
