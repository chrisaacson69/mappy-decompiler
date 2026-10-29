#!/usr/bin/env python3
"""
cdl_gap.py - the discover gate's hole check: PRG bytes the game executed (Mesen's CDL over real play)
that mappy_labeled.asm does not decode as instructions. Any such byte is a discovery hole by
definition; the gate wants none.

Found the one hole the static pipeline had (2026-10-26): $EA51-$EA8F, the door-knockback handlers
behind the shared JMP ($001C) stub at $EA46.

  py -3.14 tools/cdl_gap.py <input log> [<input log> ...]   (logs from power-on, e.g. traces/mappy_*.txt)
"""
import re
import sys
from pathlib import Path

from emu_harness.machines.nes import NES, read_input_log

from paths import ROM, LISTING, TRACES
IDLE = 2500                     # frames of no input after each log, so the player gets caught


def listing_code():
    code = bytearray(0x4000)
    for line in LISTING.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s+([0-9A-F]{4}):\s+((?:[0-9A-F]{2} )+)\s*[a-z]{3}\b', line)
        if m:
            a = int(m.group(1), 16) - 0xC000
            for i in range(len(m.group(2).split())):
                code[a + i] = 1
    return code


def executed(logs):
    out = bytearray(0x4000)
    for log in logs:
        with NES(ROM) as m:
            m.run_masks([m.mask_from_names(f) for f in read_input_log(log)] + [0] * IDLE)
            cdl = m.cdl("nesPrgRom", (TRACES / f"{log.stem}.cdl").resolve())
        for i, f in enumerate(cdl[:0x4000]):
            if f & 1:                                   # Mesen CDL bit 0: code
                out[i] = 1
    return out


def main():
    logs = [Path(a) for a in sys.argv[1:]]
    if not logs:
        sys.exit(__doc__)
    code, run = listing_code(), executed(logs)
    gap = [i for i in range(0x4000) if run[i] and not code[i]]
    print(f"executed {sum(run):,} B; listing decodes {sum(code):,} B; executed but not decoded: {len(gap)} B")
    runs = []
    for i in gap:
        if runs and i == runs[-1][1] + 1:
            runs[-1][1] = i
        else:
            runs.append([i, i])
    for a, b in runs:
        print(f"  ${a + 0xC000:04X}-${b + 0xC000:04X} ({b - a + 1} B)")
    return 1 if gap else 0


if __name__ == "__main__":
    sys.exit(main())
