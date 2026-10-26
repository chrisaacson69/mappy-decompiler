#!/usr/bin/env python3
"""
data_frontier.py - the data-walk frontier for Mappy's PRG: every absolute operand (abs, abs,X, abs,Y) in
decoded code that points into PRG bytes the listing does not decode, grouped by base address with the
named routines that read it (the provenance a data name comes from), a byte preview, and whether a label
already sits there. Read operands only; the bytes come from the ROM, the code from mappy_labeled.asm.

A base and base+1 read by the same routine (a word table read as lo/hi) are one element. A base 1-3 bytes
past a data label (no code between) is that label's field (label+N), not a gap: the walk is done at 0.

  py -3.14 mappy/data_frontier.py            -> unlabeled elements, by base
  py -3.14 mappy/data_frontier.py --all      -> labeled ones too
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

from emu_harness.cpu.m6502.disasm import ABS, ABX, ABY, MODE_LEN, OPS

HERE = Path(__file__).resolve().parent
PRG = (HERE / "Mappy (Japan).nes").read_bytes()[16:16 + 0x4000]
LINE = re.compile(r'\s+([0-9A-F]{4}):\s+((?:[0-9A-F]{2} )+)\s*([a-z]{3})\b')
LABEL = re.compile(r'^([A-Za-z_]\w*):$')


def scan():
    code, owner, refs, labels = set(), {}, [], {}
    cur, pending = None, None
    for l in (HERE / "mappy_labeled.asm").read_text(encoding="utf-8").splitlines():
        m = LABEL.match(l)
        if m:
            pending = m.group(1)
            continue
        a = re.match(r'\s+([0-9A-F]{4}):', l)
        if a and pending:
            labels[int(a.group(1), 16)] = pending
            pending = None
        m = LINE.match(l)
        if not m:
            continue
        addr, bs = int(m.group(1), 16), [int(x, 16) for x in m.group(2).split()]
        code.update(range(addr, addr + len(bs)))
        cur = labels.get(addr, cur)
        mn, mode = OPS[bs[0]]
        if mode in (ABS, ABX, ABY) and len(bs) == 3:
            t = bs[1] | bs[2] << 8
            if t >= 0xC000:
                refs.append((t, cur, mn, mode))
    return code, refs, labels


def main(show_all):
    code, refs, labels = scan()
    by = defaultdict(lambda: defaultdict(set))
    for t, who, mn, mode in refs:
        if t in code:
            continue
        base = t - 1 if (t - 1) in by and who in by[t - 1] else t
        idx = {ABX: ",x", ABY: ",y"}.get(mode, "")
        by[base][who].add(f"{mn}{idx}" + ("" if base == t else " (+1)"))
    n = 0
    for base in sorted(by):
        lab = labels.get(base)
        if not lab:                               # a field: a data label 1-3 bytes below, no code between
            k = next((k for k in (1, 2, 3) if base - k in labels and not (set(range(base - k, base)) & code)), None)
            if k:
                lab = f"{labels[base - k]}+{k}"
        if lab and not show_all:
            continue
        n += 1
        pre = " ".join(f"{PRG[(base - 0xC000 + k) & 0x3FFF]:02X}" for k in range(8))
        who = "; ".join(f"{w} [{', '.join(sorted(v))}]" for w, v in sorted(by[base].items(), key=lambda x: str(x[0])))
        print(f"${base:04X}  {lab or '-':28}  {pre}  <- {who}")
    print(f"\n{n} element(s){'' if show_all else ' unlabeled'}")


if __name__ == "__main__":
    main("--all" in sys.argv)
