#!/usr/bin/env python3
"""
render_level.py - render a Mappy round as a full 64x30 two-page playfield.

Approach (grounding discipline: run the game's OWN code, don't reimplement it):
  * The cartridge runs headless on emu-harness: `cpu.m6502` over `machines.nes.bus.Bus` with a
    `PPUPort` attached, so the ROM's own draw routines paint into a captured VRAM.
  * Drive the documented level-load sequence from sub_CD49 ($CD49):
        sub_CF69(Y=8)      fixed mansion frame   (tbl_CFA6 idx 8)
        sub_CC15(Y=byte1)  palette / HUD template (tbl_CC41)
        sub_CF69(Y=byte2)  item placement         (tbl_CFA6)
        sub_D126(Y=byte3)  mansion structure      (tbl_D185)
        ram_0170 attr fill + sub_C7C9 -> pack attribute table to $23C0/$27C0
  * The two captured nametable pages become one emu-harness `Canvas`, drawn by the library PPU.

Vertical mirroring (header flag6 bit0) => $2000 and $2400 are two side-by-side pages:
a 64x30 playfield.

Only Mappy facts live here (entry points, the round table, the draw order); the CPU, the
cartridge bus, the PPU registers and the renderer are the library's (emu-harness MIGRATION.md
row O, the Mappy re-roadmap's assets revisit). Was na1dream's CPU + nes-render via sys.path.
"""
import sys
from pathlib import Path

from emu_harness.cpu.m6502.cpu import CPU6502      # pip install -e ../emu-harness
from emu_harness.machines.nes import ppu
from emu_harness.machines.nes.bus import Bus
from emu_harness.machines.nes.canvas import Canvas
from emu_harness.machines.nes.ppuport import PPUPort

ROM = Path(__file__).parent / "Mappy (Japan).nes"

# ---- routine entry points (from raw/mappy_bank_FF.asm) ----
SUB_CD49 = 0xCD49   # full level-load orchestrator (we drive its pieces directly)
SUB_CF69 = 0xCF69   # tbl_CFA6 walker  (frame + items)
SUB_CC15 = 0xCC15   # tbl_CC41 walker  (palette / HUD template)
SUB_D126 = 0xD126   # tbl_D185 walker  (mansion structure)
SUB_C7C9 = 0xC7C9   # pack ram_0170 -> attribute tables $23C0 / $27C0
SUB_CDB7 = 0xCDB7   # fill ram_0170
TBL_CDBF = 0xCDBF   # round-attributes table (4 bytes/round)


def call(cpu, addr, *, a=0, x=0, y=0):
    """JSR `addr` and run to its matching RTS (sentinel return = $FFFF)."""
    cpu.a, cpu.x, cpu.y = a, x, y
    cpu.sp = 0xFD
    cpu.push_word(0xFFFE)          # RTS -> pull+1 = $FFFF
    cpu.pc = addr
    cpu.run_until({0xFFFF}, max_steps=2_000_000)


def build_round(round_no):
    """-> (the PPUPort the round was drawn into, the round's 4 attribute bytes)."""
    port = PPUPort()
    bus = Bus(ROM.read_bytes(), ppu=port)
    cpu = CPU6502(bus)

    # round attributes: 4 bytes at TBL_CDBF + round*4
    bonus, b1, b2, b3 = (bus.read(TBL_CDBF + round_no * 4 + i) for i in range(4))

    # documented draw order from sub_CD49 (normal-round path)
    call(cpu, SUB_CF69, y=0x08)    # fixed mansion frame
    call(cpu, SUB_CC15, y=b1)      # palette / template
    call(cpu, SUB_CF69, y=b2)      # items
    call(cpu, SUB_D126, y=b3)      # mansion structure

    # attribute source fill (sub_CD49: ram_0170[0..0x17]=0, [0x18..0x8F]=$55) then pack
    for i in range(0x18):  bus.ram[0x170 + i] = 0x00
    for i in range(0x78):  bus.ram[0x188 + i] = 0x55
    call(cpu, SUB_C7C9)            # -> attribute tables $23C0 / $27C0

    return port, (bonus, b1, b2, b3)


def playfield(vram):
    """The two nametable pages ($2000 left, $2400 right) as one 64x30 canvas."""
    field = Canvas.blank(64, 30)
    field.paste(Canvas.from_nametable(vram[0x2000:0x2400]), 0, 0)
    field.paste(Canvas.from_nametable(vram[0x2400:0x2800]), 32, 0)
    return field


def render_round(round_no, scale=2):
    port, attrs = build_round(round_no)
    rom = ROM.read_bytes()
    chr_rom = rom[16 + 0x4000: 16 + 0x4000 + 0x2000]   # CHR-ROM = file bytes after the 16KB PRG
    field = playfield(port.vram)

    # background palette captured at $3F00 (16 bytes)
    pal = list(port.vram[0x3F00:0x3F10])
    if not any(pal):
        pal = [0x0F, 0x30, 0x16, 0x21] * 4

    img = field.render(chr_rom, pal, scale=scale, master=ppu.NES_MASTER_FCEUX)
    out = Path(__file__).parent / f"mappy_round_{round_no:02d}.png"
    img.save(out)
    nonzero = sum(1 for t in field.tiles if t)
    print(f"round {round_no:2d} attrs={attrs}  nonzero-tiles={nonzero}/1920  -> {out.name}")
    return out


if __name__ == "__main__":
    rounds = [int(x, 0) for x in sys.argv[1:]] or [0]
    for r in rounds:
        render_round(r)
