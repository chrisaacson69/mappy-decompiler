#!/usr/bin/env python3
"""
render_level.py - render a Mappy round as a full 64x30 two-page playfield.

Approach (grounding discipline: run the game's OWN code, don't reimplement it):
  * Reuse the NA1 Python 6502 emulator (na1dream.cpu6502.CPU6502) verbatim -- it's a
    game-agnostic instruction emulator; only the memory map is per-game.
  * A thin Mappy memory wrapper (NROM-128: 16KB PRG mirrored to $8000 and $C000) that
    intercepts $2006/$2007 so the actual ROM draw routines paint into a captured VRAM.
  * Drive the documented level-load sequence from sub_CD49 ($CD49):
        sub_CF69(Y=8)      fixed mansion frame   (tbl_CFA6 idx 8)
        sub_CC15(Y=byte1)  palette / HUD template (tbl_CC41)
        sub_CF69(Y=byte2)  item placement         (tbl_CFA6)
        sub_D126(Y=byte3)  mansion structure      (tbl_D185)
        ram_0170 attr fill + sub_C7C9 -> pack attribute table to $23C0/$27C0
  * Hand the captured nametables + attributes + palette + CHR to the GENERIC nes_render.

Vertical mirroring (header flag6 bit0) => $2000 and $2400 are two side-by-side pages:
a 64x30 playfield. nes_render stitches them into one wide image.
"""
import sys
from pathlib import Path

NES_RENDER = r"C:\Users\Chris.Isaacson\nes-render"
NA1_TOOLS  = r"C:\Users\Chris.Isaacson\na1-decompiler\nobunaga\tools"
sys.path.insert(0, NES_RENDER)
sys.path.insert(0, NA1_TOOLS)

from na1dream.cpu6502 import CPU6502                       # generic 6502 core (reused)
from nes_render import render_tiles, NES_MASTER_FCEUX      # generic NES PPU (reused)

ROM = Path(__file__).parent / "Mappy (Japan).nes"

# ---- routine entry points (from raw/mappy_bank_FF.asm) ----
SUB_CD49 = 0xCD49   # full level-load orchestrator (we drive its pieces directly)
SUB_CF69 = 0xCF69   # tbl_CFA6 walker  (frame + items)
SUB_CC15 = 0xCC15   # tbl_CC41 walker  (palette / HUD template)
SUB_D126 = 0xD126   # tbl_D185 walker  (mansion structure)
SUB_C7C9 = 0xC7C9   # pack ram_0170 -> attribute tables $23C0 / $27C0
SUB_CDB7 = 0xCDB7   # fill ram_0170
TBL_CDBF = 0xCDBF   # round-attributes table (4 bytes/round)


class MappyMem:
    """NROM-128 memory map + a captured PPU (nametables, palettes, attributes)."""
    def __init__(self, rom_bytes):
        self.ram = bytearray(0x800)
        self.sram = bytearray(0x2000)
        # 16KB PRG = file bytes [16 : 16+0x4000]; mirrored at $8000 and $C000
        self.prg = rom_bytes[16:16 + 0x4000]
        self.vram = bytearray(0x4000)      # $0000-$3FFF: nametables + palettes
        self._latch_hi = None              # $2006 double-write latch
        self.vaddr = 0
        self.ppu_inc = 1                   # PPUCTRL bit2 -> +1 or +32
        self.trace_writes = False
        self.write_log = []

    # --- CPU bus ---
    def read(self, addr):
        addr &= 0xFFFF
        if addr < 0x2000:
            return self.ram[addr & 0x7FF]
        if 0x6000 <= addr < 0x8000:
            return self.sram[addr - 0x6000]
        if 0x8000 <= addr <= 0xBFFF:
            return self.prg[addr - 0x8000]
        if 0xC000 <= addr <= 0xFFFF:
            return self.prg[addr - 0xC000]
        if addr == 0x2002:
            return 0x80                    # vblank set -> any vblank-wait proceeds
        return 0

    def write(self, addr, val):
        addr &= 0xFFFF
        val &= 0xFF
        if addr < 0x2000:
            self.ram[addr & 0x7FF] = val
        elif 0x6000 <= addr < 0x8000:
            self.sram[addr - 0x6000] = val
        elif addr == 0x2000:
            self.ppu_inc = 32 if (val & 0x04) else 1
        elif addr == 0x2006:
            if self._latch_hi is None:
                self._latch_hi = val
            else:
                self.vaddr = ((self._latch_hi << 8) | val) & 0x3FFF
                self._latch_hi = None
        elif addr == 0x2007:
            self.vram[self.vaddr & 0x3FFF] = val
            self.vaddr = (self.vaddr + self.ppu_inc) & 0x3FFF
        # other PPU/APU/IO writes ignored

    def read_word(self, addr):
        return self.read(addr) | (self.read(addr + 1) << 8)

    def write_word(self, addr, val):
        self.write(addr, val & 0xFF); self.write(addr + 1, (val >> 8) & 0xFF)


def call(cpu, addr, *, a=0, x=0, y=0):
    """JSR `addr` and run to its matching RTS (sentinel return = $FFFF)."""
    cpu.a, cpu.x, cpu.y = a, x, y
    cpu.sp = 0xFD
    cpu.push_word(0xFFFE)          # RTS -> pull+1 = $FFFF
    cpu.pc = addr
    cpu.run_until({0xFFFF}, max_steps=2_000_000)


def build_round(round_no):
    rom = ROM.read_bytes()
    mem = MappyMem(rom)
    cpu = CPU6502(mem)

    # round attributes: 4 bytes at TBL_CDBF + round*4
    base = (TBL_CDBF - 0xC000) + round_no * 4
    bonus, b1, b2, b3 = (mem.prg[base + i] for i in range(4))

    # documented draw order from sub_CD49 (normal-round path)
    call(cpu, SUB_CF69, y=0x08)    # fixed mansion frame
    call(cpu, SUB_CC15, y=b1)      # palette / template
    call(cpu, SUB_CF69, y=b2)      # items
    call(cpu, SUB_D126, y=b3)      # mansion structure

    # attribute source fill (sub_CD49: ram_0170[0..0x17]=0, [0x18..0x8F]=$55) then pack
    for i in range(0x18):  mem.ram[0x170 + i] = 0x00
    for i in range(0x78):  mem.ram[0x188 + i] = 0x55
    call(cpu, SUB_C7C9)            # -> attribute tables $23C0 / $27C0

    return mem, (bonus, b1, b2, b3)


def render_round(round_no, scale=2):
    mem, attrs = build_round(round_no)
    chr_ = mem.prg  # placeholder; CHR comes from the ROM CHR bank, not PRG
    # CHR-ROM = file bytes after the 16KB PRG
    chr_rom = ROM.read_bytes()[16 + 0x4000: 16 + 0x4000 + 0x2000]

    # two nametable pages: $2000 (left) and $2400 (right), 32x30 each
    def page(addr):
        nt = mem.vram[addr:addr + 0x3C0]            # 960 tiles
        at = mem.vram[addr + 0x3C0:addr + 0x400]    # 64 attribute bytes
        return list(nt), bytes(at)
    nt0, at0 = page(0x2000)
    nt1, at1 = page(0x2400)

    # stitch into one 64x30 flat index list (row-major across both pages)
    stitched, sub = [], []
    from nes_render import attr_subpalette
    for row in range(30):
        for page_nt, page_at in ((nt0, at0), (nt1, at1)):
            for col in range(32):
                stitched.append(page_nt[row * 32 + col])
                sub.append(attr_subpalette(page_at, col, row, 8))

    # background palette captured at $3F00 (16 bytes)
    pal = list(mem.vram[0x3F00:0x3F10])
    if not any(pal):
        pal = [0x0F, 0x30, 0x16, 0x21] * 4

    img = render_tiles(chr_rom, stitched, pal, cols=64, rows=30,
                       subpalette=sub, master=NES_MASTER_FCEUX, scale=scale)
    out = Path(__file__).parent / f"mappy_round_{round_no:02d}.png"
    img.save(out)
    nonzero = sum(1 for t in stitched if t)
    print(f"round {round_no:2d} attrs={attrs}  nonzero-tiles={nonzero}/1920  -> {out.name}")
    return out


if __name__ == "__main__":
    rounds = [int(x, 0) for x in sys.argv[1:]] or [0]
    for r in rounds:
        render_round(r)
