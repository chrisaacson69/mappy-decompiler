#!/usr/bin/env python3
"""
state_census.py - the object state machine, observed: play input logs from power-on on Mesen and
record, for the 9 records at $0400 (state = +F), every state run (duration, x/y moved, successor)
and every write to a state byte with the writer's PC (a write-watch, so computed stores count too).

The naming evidence for the $DA42 handlers (2026-10-26). The writer PCs also found the discover hole:
the player's state-10 write ran at $EA7C, in bytes the listing then showed as data.

A state byte indexes $DA42 in a normal round and $E17A in a bonus round (is_bonus_round, $7C), so
every count is keyed by table. --poke FRAME:ADDR=VAL writes a CPU byte before that frame (a warp,
e.g. 130:7A=01 sets stage_number in round 1, so clearing it enters the round-3 bonus round); a
poked run is evidence for what the handlers do, not for how the game reaches them.

  py -3.14 tools/state_census.py <input log> [<input log> ...] [--poke F:AA=VV ...] [--idle N]
"""
import argparse
import sys
from collections import Counter, defaultdict
from pathlib import Path

from emu_harness.backends.mesen.client import read_trace, read_watch
from emu_harness.machines.nes import NES, read_input_log

from paths import ROM, TRACES
BONUS = 0x7C                    # is_bonus_round: which table the state byte indexes
TABLE = {False: "$DA42", True: "$E17A"}


def run(log, pokes, idle):
    trace, watch = ((TRACES / f"{log.stem}.{k}").resolve() for k in ("ram", "watch"))
    with NES(ROM) as m:
        masks = [m.mask_from_names(f) for f in read_input_log(log)] + [0] * idle
        m.trace("nesDebug", 0, 0x800, trace)
        m.watch("write", 0x40F, 0x48F, watch, regs=True, ranges=[("nesDebug", BONUS, 1)])
        done = 0
        for frame, addr, val in sorted(pokes):
            m.run_masks(masks[done:frame])
            m.write("nesDebug", addr, bytes([val]))
            done = frame
        m.run_masks(masks[done:])
        m.watch_off()
        m.trace_off()
    frames = [b for _, b in read_trace(trace, 0x800)]
    writes = [r for r in read_watch(watch) if r["address"] & 0xF == 0xF]
    return frames, writes


def poke(s):
    f, rest = s.split(":")
    a, v = rest.split("=")
    return int(f), int(a, 16), int(v, 16)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("logs", type=Path, nargs="+")
    ap.add_argument("--poke", type=poke, action="append", default=[])
    ap.add_argument("--idle", type=int, default=2500, help="no-input frames after each log")
    a = ap.parse_args()
    dur, succ, moved, who = defaultdict(list), Counter(), defaultdict(Counter), defaultdict(Counter)
    writers = Counter()
    for log in a.logs:
        frames, writes = run(log, a.poke, a.idle)
        for s in range(9):
            b, cur, start = 0x400 + 16 * s, None, 0
            for f, r in enumerate(frames + [None]):
                st = (bool(r[BONUS]), r[b + 15]) if r is not None else None
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
            bonus = next(v for k, v in w.items() if ":" in k)[0] != 0
            writers[(bonus, w["value"], w["cpu.pc"], "player" if w["address"] == 0x40F else "other")] += 1
    def tag(st): return f"{TABLE[st[0]]} {st[1]:02X}"
    for st in sorted(dur):
        d = dur[st]
        print(f"{tag(st)}: {len(d)} runs, {min(d)}-{max(d)} frames, most {Counter(d).most_common(2)}; "
              f"(dx, dy) {moved[st].most_common(3)}")
        print(f"    (slot, type): frames {dict(who[st])}")
        print(f"    -> {', '.join(f'{tag(b)} x{n}' for (a, b), n in sorted(succ.items()) if a == st)}")
    print("\nwriters (Mesen PC is after the store):")
    for (bonus, v, pc, kind), n in sorted(writers.items()):
        print(f"  {TABLE[bonus]} {v:02X}  pc ${pc:04X}  {kind:6}  x{n}")


if __name__ == "__main__":
    main()
