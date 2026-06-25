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

Reuses the NA1 6502 core (na1dream.cpu6502.CPU6502) verbatim; a thin subclass completes the
18 documented opcodes the VM-only build never needed. The disasm6502 OPS table is the ISA spec.
"""
import sys
from pathlib import Path

NA1_TOOLS = r"C:\Users\Chris.Isaacson\na1-decompiler\nobunaga\tools"
KOEI_TOOLS = r"C:\Users\Chris.Isaacson\koei-nes\tools"
sys.path.insert(0, NA1_TOOLS)
sys.path.insert(0, KOEI_TOOLS)
from na1dream.cpu6502 import CPU6502
import disasm6502
OPS, MODE_LEN = disasm6502.OPS, disasm6502.MODE_LEN

ROM = Path(__file__).parent / "Mappy (Japan).nes"
NMI_VEC, RESET_VEC, IRQ_VEC = 0xFFFA, 0xFFFC, 0xFFFE


class Mem:
    """NROM-128 bus + minimal PPU/IO stubs for headless tracing."""
    def __init__(self, rom):
        self.ram = bytearray(0x800)
        self.sram = bytearray(0x2000)
        self.prg = rom[16:16 + 0x4000]   # $C000-$FFFF, mirrored to $8000
        self.vaddr = 0; self._latch = None; self.ppu_inc = 1

    def read(self, a):
        a &= 0xFFFF
        if a < 0x2000:            return self.ram[a & 0x7FF]
        if 0x6000 <= a < 0x8000:  return self.sram[a - 0x6000]
        if 0x8000 <= a <= 0xBFFF: return self.prg[a - 0x8000]
        if 0xC000 <= a <= 0xFFFF: return self.prg[a - 0xC000]
        if a == 0x2002:           return 0x80   # vblank set -> waits pass
        if a == 0x2007:           return 0      # PPUDATA read stub
        return 0                                 # $4016/$4017 etc -> no buttons

    def write(self, a, v):
        a &= 0xFFFF; v &= 0xFF
        if a < 0x2000:             self.ram[a & 0x7FF] = v
        elif 0x6000 <= a < 0x8000: self.sram[a - 0x6000] = v
        elif a == 0x2000:          self.ppu_inc = 32 if (v & 4) else 1
        elif a == 0x2006:
            if self._latch is None: self._latch = v
            else: self.vaddr = ((self._latch << 8) | v) & 0x3FFF; self._latch = None
        elif a == 0x2007:          self.vaddr = (self.vaddr + self.ppu_inc) & 0x3FFF

    def read_word(self, a):  return self.read(a) | (self.read(a + 1) << 8)
    def write_word(self, a, v): self.write(a, v & 0xFF); self.write(a + 1, (v >> 8) & 0xFF)


class TracingCPU(CPU6502):
    """CPU6502 + the 18 missing documented opcodes + execution trace hooks."""
    def addr_zp_y(self):
        a = (self.mem.read(self.pc) + self.y) & 0xFF; self.pc += 1; return a

    def _dispatch(self, op):
        # --- the 18 opcodes the VM-only build omitted ---
        if   op == 0x01: self.a |= self.mem.read(self.addr_ind_x()); self.set_nz(self.a)   # ORA (zp,X)
        elif op == 0x21: self.a &= self.mem.read(self.addr_ind_x()); self.set_nz(self.a)   # AND (zp,X)
        elif op == 0x41: self.a ^= self.mem.read(self.addr_ind_x()); self.set_nz(self.a)   # EOR (zp,X)
        elif op == 0x61: self._adc(self.mem.read(self.addr_ind_x()))                       # ADC (zp,X)
        elif op == 0xC1: self._cmp(self.a, self.mem.read(self.addr_ind_x()))               # CMP (zp,X)
        elif op == 0x94: self.mem.write(self.addr_zp_x(), self.y)                          # STY zp,X
        elif op == 0x96: self.mem.write(self.addr_zp_y(), self.x)                          # STX zp,Y
        elif op == 0xB4: self.y = self.mem.read(self.addr_zp_x()); self.set_nz(self.y)     # LDY zp,X
        elif op == 0xB6: self.x = self.mem.read(self.addr_zp_y()); self.set_nz(self.x)     # LDX zp,Y
        elif op == 0xBC: self.y = self.mem.read(self.addr_abs_x()); self.set_nz(self.y)    # LDY abs,X
        elif op == 0xBE: self.x = self.mem.read(self.addr_abs_y()); self.set_nz(self.x)    # LDX abs,Y
        elif op == 0xCC: self._cmp(self.y, self.mem.read(self.addr_abs()))                 # CPY abs
        elif op == 0xEC: self._cmp(self.x, self.mem.read(self.addr_abs()))                 # CPX abs
        elif op == 0xD6:  # DEC zp,X
            ad = self.addr_zp_x(); v = (self.mem.read(ad) - 1) & 0xFF; self.mem.write(ad, v); self.set_nz(v)
        elif op == 0xF6:  # INC zp,X
            ad = self.addr_zp_x(); v = (self.mem.read(ad) + 1) & 0xFF; self.mem.write(ad, v); self.set_nz(v)
        elif op == 0xDE:  # DEC abs,X
            ad = self.addr_abs_x(); v = (self.mem.read(ad) - 1) & 0xFF; self.mem.write(ad, v); self.set_nz(v)
        elif op == 0xFE:  # INC abs,X
            ad = self.addr_abs_x(); v = (self.mem.read(ad) + 1) & 0xFF; self.mem.write(ad, v); self.set_nz(v)
        elif op == 0x00:  # BRK -> vector through IRQ ($FFFE)
            self.push_word((self.pc + 1) & 0xFFFF); self.push(0x30)
            self.i = True; self.pc = self.mem.read_word(IRQ_VEC)
        else:
            super()._dispatch(op)

    def nmi(self):
        self.push_word(self.pc); self.push(0x20)
        self.i = True; self.pc = self.mem.read_word(NMI_VEC)


def trace(frames=4000, frame_budget=12000, max_steps=80_000_000):
    rom = ROM.read_bytes()
    mem = Mem(rom)
    cpu = TracingCPU(mem)
    cpu.pc = mem.read_word(RESET_VEC); cpu.sp = 0xFD

    code = bytearray(0x4000)          # PRG coverage: 1 = executed (CODE)
    edges = {}                        # src_addr -> set of call/jump targets
    indirect = {}                     # site_addr -> set of resolved targets (jump tables)
    steps = 0; frame = 0; since_nmi = 0
    in_prg = lambda a: 0xC000 <= a <= 0xFFFF or 0x8000 <= a <= 0xBFFF
    norm = lambda a: (a & 0x3FFF)     # $8000/$C000 both -> same 16K

    while frame < frames and steps < max_steps:
        pc = cpu.pc
        op = mem.read(pc)
        ilen = 1 + MODE_LEN.get(OPS[op][1], 0) if op in OPS else 1
        if in_prg(pc):
            for k in range(ilen):
                code[norm(pc + k)] = 1
            if op == 0x20:    # JSR abs
                edges.setdefault(norm(pc), set()).add(mem.read_word(pc + 1) & 0xFFFF)
            elif op == 0x4C:  # JMP abs
                edges.setdefault(norm(pc), set()).add(mem.read_word(pc + 1) & 0xFFFF)
            elif op == 0x6C:  # JMP (abs) -- resolve at runtime
                ptr = mem.read_word(pc + 1)
                tgt = mem.read(ptr) | (mem.read((ptr & 0xFF00) | ((ptr + 1) & 0xFF)) << 8)
                indirect.setdefault(norm(pc), set()).add(tgt & 0xFFFF)
        try:
            cpu.step()
        except NotImplementedError as e:
            print(f"[missing opcode] {e}  (op ${op:02X} at ${pc:04X})"); break
        except Exception as e:
            print(f"[halt] {type(e).__name__}: {e} at ${pc:04X}"); break
        steps += 1; since_nmi += 1
        if since_nmi >= frame_budget:
            cpu.nmi(); since_nmi = 0; frame += 1

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
