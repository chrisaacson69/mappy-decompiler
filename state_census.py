#!/usr/bin/env python3
"""
state_census.py - the object state machine, observed: play input logs from power-on on Mesen and
record, for the 9 records at $0400 (state = +F), every state run (duration, x/y moved, successor)
and every write to a state byte with the writer's PC (a write-watch, so computed stores count too).

The naming evidence for the $DA42 handlers (2026-10-26). The writer PCs also found the discover hole:
the player's state-10 write ran at $EA7C, in bytes the listing then showed as data.

  py -3.14 mappy/state_census.py <input log> [<input log> ...]   (e.g. _scratch/mappy_*.txt)
"""
import sys
from collections import Counter, defaultdict
from pathlib import Path

from emu_harness.backends.mesen.client import read_trace, read_watch
from emu_harness.machines.nes import NES, read_input_log

HERE = Path(__file__).resolve().parent
ROM = HERE / "Mappy (Japan).nes"
SCRATCH = HERE / "_scratch"
IDLE = 2500                     # frames of no input after each log, so the player gets caught


def run(log):
    trace, watch = ((SCRATCH / f"{log.stem}.{k}").resolve() for k in ("ram", "watch"))
    with NES(ROM) as m:
        masks = [m.mask_from_names(f) for f in read_input_log(log)] + [0] * IDLE
        m.trace("nesDebug", 0, 0x800, trace)
        m.watch("write", 0x40F, 0x48F, watch, regs=True)
        m.run_masks(masks)
        m.watch_off()
        m.trace_off()
    frames = [b for _, b in read_trace(trace, 0x800)]
    writes = [r for r in read_watch(watch) if r["address"] & 0xF == 0xF]
    return frames, writes


def main():
    logs = [Path(a) for a in sys.argv[1:]]
    if not logs:
        sys.exit(__doc__)
    dur, succ, moved, who = defaultdict(list), Counter(), defaultdict(Counter), defaultdict(Counter)
    writers = Counter()
    for log in logs:
        frames, writes = run(log)
        for s in range(9):
            b, cur, start = 0x400 + 16 * s, None, 0
            for f, r in enumerate(frames + [None]):
                st = r[b + 15] if r is not None else None
                if st != cur:
                    if cur is not None:
                        p, q = frames[start], frames[f - 1]
                        dur[cur].append(f - start)
                        moved[cur][(q[b + 1] - p[b + 1], q[b + 3] - p[b + 3])] += 1
                        if st is not None:
                            succ[(cur, st)] += 1
                    cur, start = st, f
                if r is not None:
                    who[st][(s, r[b + 5])] += 1
        for w in writes:
            writers[(w["value"], w["cpu.pc"], "player" if w["address"] == 0x40F else "other")] += 1
    for st in sorted(dur):
        d = dur[st]
        print(f"state {st:02X}: {len(d)} runs, {min(d)}-{max(d)} frames, most {Counter(d).most_common(2)}; "
              f"(dx, dy) {moved[st].most_common(3)}")
        print(f"    (slot, type): frames {dict(who[st])}")
        print(f"    -> {', '.join(f'{b:02X} x{n}' for (a, b), n in sorted(succ.items()) if a == st)}")
    print("\nwriters (Mesen PC is after the store):")
    for (v, pc, kind), n in sorted(writers.items()):
        print(f"  state {v:02X}  pc ${pc:04X}  {kind:6}  x{n}")


if __name__ == "__main__":
    main()
