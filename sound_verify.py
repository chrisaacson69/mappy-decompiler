#!/usr/bin/env python3
"""
sound_verify.py - the sound lane's check: does the headless engine write what the real game writes?

Plays an input log on Mesen and records, in CPU-cycle order:
  * every write the GAME makes into the sound engine's RAM ($0600-$06FF triggers / voice params,
    $00F0-$00FF), i.e. from a PC outside the engine ($F49F-$F83A);
  * every entry to init_apu_channels_and_frame_counter ($F4B5), init_sound_voices ($F4BF) and
    update_sound_frame ($F4F1), whoever calls them (the main loop, the NMI on a lag frame, the game);
  * every write to the APU registers ($4000-$4017): the reference stream.
Then replays the game's writes and calls, in the same order, into the engine on the headless CPU
(the library's sound.tap on a Bus) and compares the two APU streams write for write.

  py -3.14 mappy/sound_verify.py <input log> [--idle N]
"""
import argparse
import sys
from pathlib import Path

from emu_harness.backends.mesen.client import read_watch
from emu_harness.cpu.m6502.cpu import CPU6502
from emu_harness.machines.nes import NES, read_input_log
from emu_harness.machines.nes.bus import Bus
from emu_harness.machines.nes.sound import Recorder, tap
from sound_capture import ROM, call

from paths import ROM, TRACES
ENGINE = (0xF49F, 0xF83D)          # Mesen's PC is after the store: allow the last store's length
INIT_APU, INIT_VOICES, TICK = 0xF4B5, 0xF4BF, 0xF4F1


def record(log, idle):
    paths = {k: (TRACES / f"sv_{k}.watch").resolve() for k in ("ram", "zp", "apu", "init", "voices", "tick")}
    with NES(ROM) as m:
        masks = [m.mask_from_names(f) for f in read_input_log(log)] + [0] * idle
        m.watch("write", 0x0600, 0x06FF, paths["ram"], regs=True)
        m.watch("write", 0x00F0, 0x00FF, paths["zp"], regs=True)
        m.watch("write", 0x4000, 0x4017, paths["apu"], regs=True)
        m.watch("exec", INIT_APU, INIT_APU, paths["init"], regs=True)
        m.watch("exec", INIT_VOICES, INIT_VOICES, paths["voices"], regs=True)
        m.watch("exec", TICK, TICK, paths["tick"], regs=True)
        m.run_masks(masks)
        m.watch_off()
    return {k: read_watch(p) for k, p in paths.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log", type=Path)
    ap.add_argument("--idle", type=int, default=600)
    a = ap.parse_args()
    w = record(a.log, a.idle)

    events = []                                                   # (cycle, kind, payload)
    for k in ("ram", "zp"):
        for r in w[k]:
            if not ENGINE[0] <= r["cpu.pc"] <= ENGINE[1]:
                events.append((r["cpu.cycleCount"], "poke", (r["address"], r["value"])))
    inits = [r["cpu.cycleCount"] for r in w["init"]]
    events += [(c, "init", None) for c in inits]
    # init_apu falls into init_sound_voices: that entry is the same call, not a second one
    events += [(r["cpu.cycleCount"], "voices", None) for r in w["voices"]
               if not any(0 < r["cpu.cycleCount"] - c < 100 for c in inits)]
    events += [(r["cpu.cycleCount"], "tick", None) for r in w["tick"]]
    events.sort(key=lambda e: e[0])

    ref = [(r["address"], r["value"]) for r in w["apu"] if r["address"] not in (0x4014, 0x4016)]
    rec = Recorder()
    bus = tap(Bus(ROM), rec)
    cpu = CPU6502(bus)
    counts = {"poke": 0, "init": 0, "voices": 0, "tick": 0}
    for _, kind, payload in events:
        counts[kind] += 1
        if kind == "poke":
            bus.ram[payload[0]] = payload[1]
        else:
            call(cpu, {"init": INIT_APU, "voices": INIT_VOICES, "tick": TICK}[kind])
    got = [(a_, v) for _, a_, v in rec.writes]

    print(f"replayed {counts}")
    print(f"APU writes: Mesen {len(ref):,}, headless {len(got):,}")
    k = next((i for i in range(min(len(ref), len(got))) if ref[i] != got[i]), None)
    if k is None and len(ref) == len(got):
        print("identical, write for write")
        return 0
    k = k if k is not None else min(len(ref), len(got))
    print(f"first difference at write {k}: Mesen {ref[k:k+4]}  headless {got[k:k+4]}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
