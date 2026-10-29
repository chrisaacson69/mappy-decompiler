#!/usr/bin/env python3
"""
live_verify.py - the Live verification gate: the game's own per-object step, run headless over live
RAM for every input, must reproduce what the live game did; and a planted fault must fail it.

The step is one pass of update_and_respawn_objects' loop ($D8E0): set_object_intent, dispatch_object_state
(the 23 / 10 state handlers and everything below them) and draw_object, for one slot. On Mesen, an exec
watch at the loop head ($D8E0) and the loop exit ($D8F4) dumps all 2 KB of RAM each time, so a slot's
"after" is the next hit's "before". An NMI watch ($C2EF) marks a step an interrupt landed in (its
writes are not the step's), and those steps are skipped and counted.

Headless (emu-harness cpu.m6502 over machines.nes.bus), each "before" is loaded, the CPU starts at $D8E0
with the live stack pointer and runs to the next $D8E0 / $D8F4; the RAM must then equal the "after",
byte for byte, except the stack page ($0100-$01FF: only return addresses differ).

  py -3.14 tools/live_verify.py <input log> [--poke F:AA=VV ...] [--idle N] [--fault]
    --fault plants one changed instruction in the headless ROM (walk_step's frame counter +1 -> +2,
    $DEFC); the check must then fail.
  py -3.14 tools/live_verify.py --suite
    the gate: every run in SUITE identical, the planted fault caught, and every reachable state seen
    (normal 02-2C, bonus 00-12 except 10, which no instruction writes).
"""
import argparse
import sys
from collections import Counter
from pathlib import Path

from emu_harness.backends.mesen.client import read_watch
from emu_harness.cpu.m6502.cpu import CPU6502
from emu_harness.machines.nes import NES, read_input_log
from emu_harness.machines.nes.bus import Bus

from paths import ROM, TRACES
LOOP, EXIT, NMI = 0xD8E0, 0xD8F4, 0xC2EF
FAULT = (0xDEFD, 0x01, 0x02)        # walk_step: adc #$01 (+7 += 1) -> adc #$02
# (input log, pokes, idle frames, what it adds): play logs, then warps for what play never reached
SUITE = [
    ("mappy_tas60_start60.txt", [], 300, "play"),
    ("mappy_robust4_start300.txt", [], 1500, "play; the catches (08, 2A, 2C)"),
    ("mappy_route_tas60_start60.txt", [], 1500, "play"),
    ("mappy_bonus_lr40.txt", ["130:7A=01"], 600, "bonus round 3"),
    ("mappy_bonus_lr40.txt", ["130:7A=01", "3975:401=05", "3975:403=18"], 600, "bonus: Mappy on the goal balloon"),
    ("mappy_tas60_start60.txt", ["130:66=01", "130:67=02"], 1500, "round timer: HURRY, the extra cat, the coin"),
    ("mappy_bonus_lr12.txt", ["130:7A=06"], 900, "round 8 (bells)"),
    ("mappy_bonus_lr12.txt", ["130:7A=06", "3777:401=37", "3777:403=06", "3777:431=37", "3777:433=0A"], 900,
     "round 8: Mappy under a bell, a Meowky below (26, 28)"),
    ("mappy_bonus_lr12.txt", ["130:7A=0A"], 900, "round 12 (floor traps)"),
    ("mappy_tas60_start60.txt", [f"200:{a:03X}=80" for a in range(0x202, 0x22B, 8)], 300,
     "round 1, trampolines broken: cats fall through (22)"),
]
REACHABLE = {(s, False) for s in range(0x02, 0x2E, 2)} | {(s, True) for s in range(0x00, 0x14, 2) if s != 0x10}


def record(log, pokes, idle):
    paths = {k: (TRACES / f"lv_{k}.watch").resolve() for k in ("loop", "exit", "nmi")}
    with NES(ROM) as m:
        masks = [m.mask_from_names(f) for f in read_input_log(log)] + [0] * idle
        ram = [("nesDebug", 0, 0x800)]
        m.watch("exec", LOOP, LOOP, paths["loop"], regs=True, ranges=ram)
        m.watch("exec", EXIT, EXIT, paths["exit"], regs=True, ranges=ram)
        m.watch("exec", NMI, NMI, paths["nmi"], regs=True)
        done = 0
        for frame, addr, val in sorted(pokes):
            m.run_masks(masks[done:frame])
            m.write("nesDebug", addr, bytes([val]))
            done = frame
        m.run_masks(masks[done:])
        m.watch_off()
    rows = {k: read_watch(p) for k, p in paths.items()}
    for k in ("loop", "exit"):
        for r in rows[k]:
            r["ram"] = next(v for kk, v in r.items() if ":" in kk)
            r["kind"] = k
    return rows


def poke(s):
    f, rest = s.split(":")
    a, v = rest.split("=")
    return int(f), int(a, 16), int(v, 16)


def check(log, pokes, idle, fault=False):
    """-> (identical, different, skipped, Counter of (state, bonus) verified, first difference or None)."""
    rows = record(log, pokes, idle)
    hits = sorted(rows["loop"] + rows["exit"], key=lambda r: r["cpu.cycleCount"])
    nmis = sorted(r["cpu.cycleCount"] for r in rows["nmi"])

    rom = bytearray(ROM.read_bytes())
    if fault:
        off = 16 + FAULT[0] - 0xC000
        assert rom[off] == FAULT[1], "the fault site moved"
        rom[off] = FAULT[2]
    import bisect
    ok = bad = skipped = 0
    states, first_bad = Counter(), None
    for pre, post in zip(hits, hits[1:]):
        if pre["kind"] != "loop":
            continue                                   # the loop exit starts no step
        c0, c1 = pre["cpu.cycleCount"], post["cpu.cycleCount"]
        if bisect.bisect_right(nmis, c0) != bisect.bisect_right(nmis, c1):
            skipped += 1                               # an NMI ran inside this step
            continue
        bus = Bus(bytes(rom))
        bus.ram[:] = pre["ram"]
        cpu = CPU6502(bus)
        cpu.a, cpu.x, cpu.y, cpu.sp = pre["cpu.a"], pre["cpu.x"], pre["cpu.y"], pre["cpu.sp"]
        cpu.pc = LOOP
        cpu.step()
        cpu.run_until({LOOP, EXIT}, max_steps=200_000)
        got, want = bytes(bus.ram), post["ram"]
        slot = (pre["ram"][0x1E] - 0x00) >> 4
        state = pre["ram"][0x40F + 16 * slot], bool(pre["ram"][0x7C])
        diff = [i for i in range(0x800) if not 0x100 <= i < 0x200 and got[i] != want[i]]
        if diff:
            bad += 1
            first_bad = first_bad or (pre["frame"], slot, state, [(hex(i), got[i], want[i]) for i in diff[:6]])
        else:
            ok += 1
            states[state] += 1
    return ok, bad, skipped, states, first_bad


def report(ok, bad, skipped, states, first_bad, label=""):
    print(f"{label}steps {ok + bad + skipped:,}: identical {ok:,}, different {bad:,}, skipped (NMI inside) {skipped:,}")
    print("    states:", " ".join(f"{s:02X}{'b' if b else ''}x{n}" for (s, b), n in sorted(states.items())))
    if first_bad:
        print("    first difference: frame %d slot %d state %s: %s" % first_bad)


def suite():
    total, seen, failed = Counter(), Counter(), False
    for log, pokes, idle, what in SUITE:
        ok, bad, skipped, states, first = check(TRACES / log, [poke(p) for p in pokes], idle)
        report(ok, bad, skipped, states, first, f"[{what}] ")
        total.update(identical=ok, different=bad, skipped=skipped)
        seen.update(states)
        failed |= bad > 0
    ok, bad, *_ = check(TRACES / SUITE[0][0], [], SUITE[0][2], fault=True)
    caught = bad > 0
    print(f"[planted fault: walk_step +1 -> +2] {bad:,} of {ok + bad:,} steps differ: {'caught' if caught else 'NOT CAUGHT'}")
    missing = sorted(REACHABLE - set(seen))
    print(f"total: {total['identical']:,} identical, {total['different']:,} different, {total['skipped']:,} skipped;"
          f" reachable states never seen: {['%02X%s' % (s, 'b' if b else '') for s, b in missing] or 'none'}")
    return 0 if not failed and caught and not missing else 1


def main():
    if "--suite" in sys.argv:
        return suite()
    ap = argparse.ArgumentParser()
    ap.add_argument("log", type=Path)
    ap.add_argument("--poke", type=poke, action="append", default=[])
    ap.add_argument("--idle", type=int, default=300)
    ap.add_argument("--fault", action="store_true")
    a = ap.parse_args()
    ok, bad, skipped, states, first = check(a.log, a.poke, a.idle, a.fault)
    report(ok, bad, skipped, states, first, "[planted fault] " if a.fault else "")
    return 0 if (bad == 0) != a.fault else 1


if __name__ == "__main__":
    sys.exit(main())
