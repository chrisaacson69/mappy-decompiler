#!/usr/bin/env python3
"""
trace_codegraph.py - Phase A: discover Mappy's code/data map + call graph by EXECUTION.

Method (the "all-data-by-default" inversion): assume every PRG byte is data; carve out
bytes as CODE the moment execution touches them. Run the ROM headless from RESET through
boot + the attract/demo (which is the game playing itself, ch6), firing NMI each frame so
the main loop advances. Log:
  * coverage bitmap  -> which bytes are CODE (executed)
  * JSR/JMP edges    -> the call graph
  * indirect JMP targets (resolved at runtime -> the jump tables static sweep can't follow)

The 6502 is emu-harness's shared core (emu_harness.cpu.m6502.cpu, MIGRATION.md row C); the
coverage recorder is emu-harness's cpu.m6502.coverage (row R), lifted from this script, and the
bus is machines/nes/bus (its own NROM stub gave the same coverage, byte for byte).
"""
import sys
from pathlib import Path

from emu_harness.cpu.m6502.cpu import CPU6502
from emu_harness.cpu.m6502.coverage import trace_coverage
from emu_harness.cpu.m6502.descent import Window
from emu_harness.machines.nes.bus import Bus

ROM = Path(__file__).parent / "Mappy (Japan).nes"
NMI_VEC, RESET_VEC, IRQ_VEC = 0xFFFA, 0xFFFC, 0xFFFE


TracingCPU = CPU6502      # the name the rest of this script (and its readers) use


def trace(frames=4000, frame_budget=12000, max_steps=80_000_000):
    rom = ROM.read_bytes()
    mem = Bus(rom)                    # NROM-128: the 16K at $8000 and $C000
    cpu = TracingCPU(mem)
    cpu.pc = mem.read_word(RESET_VEC); cpu.sp = 0xFD
    cov = trace_coverage(cpu, Window(rom[16:16 + 0x4000], 0xC000, mirrors=(0x8000,)), ticks=frames,
                         tick_every=frame_budget, max_steps=max_steps)
    if cov.halt:
        print(cov.halt)
    code, edges, indirect, steps, frame = cov.code, cov.edges, cov.indirect, cov.steps, cov.ticks

    covered = sum(code)
    print(f"steps={steps:,}  frames={frame}")
    print(f"CODE bytes : {covered:,} / 16384  ({100*covered/0x4000:.1f}% of PRG)")
    print(f"call sites : {len(edges)} direct (JSR/JMP),  {len(indirect)} indirect (jump-table sites)")
    # save artifacts
    out = Path(__file__).parent
    (out / "coverage.bin").write_bytes(bytes(code))
    targets = sorted({t for s in edges.values() for t in s} | {t for s in indirect.values() for t in s})
    routine_targets = sorted(t for t in targets if 0xC000 <= t <= 0xFFFF or 0x8000 <= t <= 0xBFFF)
    print(f"distinct call/jump targets in PRG: {len(routine_targets)}")
    with open(out / "codegraph.txt", "w") as f:
        f.write(f"# coverage={covered}/16384  edges={len(edges)}  indirect={len(indirect)}\n")
        f.write("## indirect JMP sites (jump tables) and resolved targets:\n")
        for site in sorted(indirect):
            tg = " ".join(f"${t:04X}" for t in sorted(indirect[site]))
            f.write(f"  ${0xC000+site:04X} -> {tg}\n")
        f.write("## direct call/jump targets (sorted):\n")
        for t in routine_targets:
            f.write(f"  ${t:04X}\n")
    print(f"wrote coverage.bin, codegraph.txt")
    return code, edges, indirect


if __name__ == "__main__":
    fr = int(sys.argv[1]) if len(sys.argv) > 1 else 4000
    trace(frames=fr)
