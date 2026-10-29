"""Does Mappy carry hidden state (RNG / frame-counter phase) into a round?

Press Start at different frames (title, attract demo, ...), wait for the round-1 player to
go live, then play the SAME in-round inputs (a search log minus its boot prefix). If every
start gives the same per-frame RAM from "live" onward, the round is a pure function of the
in-round inputs: one seed, nothing to overfit and nothing to manipulate. If not, report the
first frame and the bytes that differ.

  py -3.14 tools/seed_test.py <search log> [--prefix 124] [--starts 60 61 62 97 300 1000 2000]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from paths import ROM, TRACES
from emu_harness.machines.nes import NES, read_input_log  # pip install -e ../emu-harness

DEMO_FLAG, P_STATE, ROUND, LIVES = 0x42, 0x40F, 0x7A, 0x70


def run(start_at: int, masks: list[int], trace: Path) -> tuple[int, list[bytes]]:
    with NES(ROM) as m:
        m.step(frames=start_at)
        while m.ram(DEMO_FLAG)[0] != 1:
            m.step(["start"])
            m.step()
        while m.ram(P_STATE)[0] == 0:
            m.step()
        live = m.frame()
        m.trace("nesDebug", 0, 0x800, trace.resolve())
        m.run_masks(masks)
        m.trace_off()
    data = trace.read_bytes()
    return live, [data[i + 1:i + 0x801] for i in range(0, len(data), 0x801)]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("log", type=Path)
    ap.add_argument("--prefix", type=int, default=124, help="boot frames in the log before 'live'")
    ap.add_argument("--starts", type=int, nargs="*", default=[60, 61, 62, 97, 300, 1000, 2000])
    a = ap.parse_args()
    out = TRACES
    with NES(ROM) as m:   # only for the mask encoding
        masks = [m.mask_from_names(f) for f in read_input_log(a.log)[a.prefix:]]
    runs = {}
    for s in a.starts:
        live, frames = run(s, masks, out / f"seed_{s}.trace")
        last = frames[-1]
        runs[s] = frames
        print(f"start pressed from frame {s:>5}: live at {live:>5}; after {len(frames)} frames "
              f"round {last[ROUND] + 1} lives {last[LIVES]} state ${last[P_STATE]:02X}", flush=True)
    base_s = a.starts[0]
    base = runs[base_s]
    for s in a.starts[1:]:
        fr = runs[s]
        k = next((k for k in range(min(len(base), len(fr))) if base[k] != fr[k]), None)
        if k is None:
            print(f"start {s}: RAM identical to start {base_s} on every frame")
            continue
        diff = [i for i in range(0x800) if base[k][i] != fr[k][i]]
        ever = sorted({i for kk in range(len(base)) for i in range(0x800) if base[kk][i] != fr[kk][i]})
        print(f"start {s}: first RAM difference at frame {k}: "
              + " ".join(f"${i:03X}={base[k][i]:02X}/{fr[k][i]:02X}" for i in diff[:12])
              + f"  | {len(ever)} addresses ever differ: "
              + " ".join(f"${i:03X}" for i in ever[:24]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
