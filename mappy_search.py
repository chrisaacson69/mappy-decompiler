"""Mappy adapter for emu-harness's segment search: play real rounds by search, headless Mesen.

The adapter is the game knowledge (RAM map, death, goal, objective, action space); the loop
is emu_harness.search.Searcher. Seeds are Start-press frames (each sets the frame-counter
phase $21 the round inherits); the goal is the last item of the target round, and restarts
must beat the best goal frame so far. Each seed's result is an input log from power-on,
re-run in a fresh instance with no savestates as the independent check.

RAM used (ch6 + measured 2026-10-02 by demo_in_real_game.py):
  $040F player state ($08 caught -> $2A -> $2C death anim), $70 p1 reserve lives,
  $7A round (0-based), $7B items left this round (10 on round 1), $71-$74 score (BCD, hi..lo),
  $42 demo flag (1 = real game).
  Items: 8-byte records at $0260, $81 bytes in all; +0 state (2 present, 4 being taken,
  0 gone), +4 horizontal position, +5 floor. Taken when +5 == player $0403 (floor) and
  |+4 - $0401| < 2 ($E660). Verified against the pickup frames of the demo replay.
Pad (read_and_decode_input $C1C9): only Left/Right (movement) and A/B (door action) matter.

  TAS for one phase:   py -3.14 mappy/mappy_search.py --starts 60 --restarts 3
  phase-robust run:    py -3.14 mappy/mappy_search.py --starts 60 61 97 300 --restarts 2
"""
from __future__ import annotations

import argparse
import sys
import time
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROM = HERE / "Mappy (Japan).nes"
sys.path.insert(0, str(HERE.parents[1] / "emu-harness"))
from emu_harness.machines.nes import KEYS, NES, write_input_log  # noqa: E402
from emu_harness.search import Searcher, Verdict  # noqa: E402

LEFT, RIGHT, A = (1 << KEYS.index(k) for k in ("left", "right", "a"))
P_X, P_Y, P_STATE, DEMO_FLAG = 0x400, 0x401, 0x40F, 0x42
LIVES, ROUND, ITEMS, SCORE = 0x70, 0x7A, 0x7B, slice(0x71, 0x75)
P_FLOOR, ITEM_TABLE, ITEM_BYTES = 0x403, 0x260, 0x81
FLOOR_COST = 40   # a floor change costs a trampoline trip; weight it like 40 columns
DEATH_STATES = {0x08, 0x2A, 0x2C}
FRAME_PHASE = 0x21   # free-running frame counter, carried into the round (seed_test.py)


@dataclass
class Obs:
    state: int
    lives: int
    round: int
    items: int
    score: int
    x: int
    y: int
    near: int       # distance to the nearest present item (0 if none)


def bcd(b: bytes) -> int:
    return int(b.hex())


class MappyAdapter:
    def __init__(self, seg_frames: int, target_round: int, shape: bool = True):
        self.seg = seg_frames
        self.target = target_round
        self.shape = shape

    def sample(self, rng) -> list[int]:
        """Demo-script-shaped commands: hold a direction (or none) for 4..48 frames,
        sometimes opening with a one-frame A press (door)."""
        masks, held = [], rng.choice((LEFT, RIGHT, 0))
        while len(masks) < self.seg:
            if rng.random() < 0.5:
                held = rng.choice((LEFT, RIGHT, 0))
            n = 4 * rng.randint(1, 12)
            press = A if rng.random() < 0.15 else 0
            masks += [held | press] + [held] * (n - 1)
        return masks[:self.seg]

    def observe(self, c) -> Obs:
        r = c.ram(0, 0x800)
        px, pf = r[P_Y], r[P_FLOOR]
        d = [abs(r[i + 4] - px) + FLOOR_COST * abs(r[i + 5] - pf) // 4
             for i in range(ITEM_TABLE, ITEM_TABLE + r[ITEM_BYTES], 8) if r[i] == 2]
        return Obs(r[P_STATE], r[LIVES], r[ROUND], r[ITEMS], bcd(r[SCORE]), r[P_X], r[P_Y],
                   min(d, default=0))

    def judge(self, o: Obs, base: Obs) -> Verdict:
        dead = o.state in DEATH_STATES or o.lives < base.lives
        # rounds dominate, then items taken this round, then points as the tie-break
        score = o.round * 100_000 + (64 - o.items) * 1000 + o.score / 1000
        if self.shape:
            score -= o.near   # < 1000 on any board, so one item still outweighs it
        # The clock stops at the last item of the target round (the clear transition after
        # it runs on its own), or at any later round.
        last = self.target - 1
        goal = o.round > last or (o.round == last and o.items == 0)
        return Verdict(score, dead=dead, goal=goal)

    def describe(self, o: Obs) -> str:
        return (f"round {o.round + 1} items left {o.items:>2} score {o.score:>7} "
                f"lives {o.lives} state ${o.state:02X} near {o.near:>3}")


def boot(rom: Path, start_at: int) -> tuple[str, list[int], int]:
    """Power on, press Start from frame `start_at`, run until the round-1 player is live.
    The press frame sets the frame-counter phase $21 the round inherits (seed_test.py).
    Returns the savestate, the power-on input log, and $21 at live."""
    with NES(rom) as m:
        m.step(frames=start_at)
        while m.ram(DEMO_FLAG)[0] != 1:
            m.step(["start"])
            m.step()
        while m.ram(P_STATE)[0] == 0:
            m.step()
        assert m.input_log_valid
        return m.save(), list(m.inputs), m.ram(FRAME_PHASE)[0]


def replay(rom: Path, log: list[int]) -> bytes:
    """Independent check: replay the whole log from power-on in a fresh instance."""
    with NES(rom) as m:
        m.run_masks(log)
        return m.ram(0, 0x800)


class _RamView:
    def __init__(self, ram: bytes):
        self._r = ram

    def ram(self, addr: int, n: int = 1) -> bytes:
        return self._r[addr:addr + n]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rounds", type=int, default=1, help="goal: clear this many rounds")
    ap.add_argument("--starts", type=int, nargs="+", default=[60],
                    help="Start-press frames = seeds (frame-counter phases). One = TAS for "
                         "that phase; several = a run that must survive all of them")
    ap.add_argument("--restarts", type=int, default=1, help="searches; each must beat the best")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--candidates", type=int, default=32)
    ap.add_argument("--seg", type=int, default=96, help="frames per segment")
    ap.add_argument("--seed", type=int, default=1, help="first search seed")
    ap.add_argument("--minutes", type=float, default=30, help="per restart")
    ap.add_argument("--no-shape", dest="shape", action="store_false",
                    help="drop the nearest-item distance from the score")
    ap.add_argument("--tag", default="")
    a = ap.parse_args()
    out = HERE / "_scratch"
    out.mkdir(exist_ok=True)

    boots = [boot(ROM, s) for s in a.starts]
    for s, (_, prefix, phase) in zip(a.starts, boots):
        print(f"seed: Start from frame {s}: live after {len(prefix)} frames, $21 = ${phase:02X}")
    adapter = MappyAdapter(a.seg, a.rounds, a.shape)
    best = None
    with Searcher(lambda: NES(ROM, clean_battery=False), adapter, workers=a.workers) as srch:
        for k in range(a.restarts):
            sd = a.seed + k
            print(f"\n== search seed {sd}" + (f", to beat {best.goal_frame} frames" if best else ""))
            res = srch.search([b[0] for b in boots], candidates=a.candidates, seed=sd,
                              max_seconds=a.minutes * 60,
                              bound=best.goal_frame if best else None)
            verdict = (f"GOAL in {res.goal_frame} frames ({res.goal_frame / 60.0988:.2f} s)"
                       if res.goal else ("pruned" if res.pruned else "stopped"))
            print(f"-- {verdict}; {res.candidates_run} runs, {res.backtracks} backtracks, "
                  f"{res.seconds:.0f}s wall")
            if res.goal and (best is None or res.goal_frame < best.goal_frame):
                best = res
    if best is None:
        print("no run reached the goal")
        return 1

    tag = a.tag or f"r{a.rounds}_" + "-".join(map(str, a.starts))
    print(f"\nBEST: goal {best.goal_frame} frames after live "
          f"({best.goal_frame / 60.0988:.2f} s), over {len(a.starts)} seed(s)")
    ok = True
    for s, (_, prefix, phase) in zip(a.starts, boots):
        log = prefix + best.inputs
        path = out / f"mappy_{tag}_start{s}.txt"
        write_input_log(path, log, f"Mappy (Japan) search {tag}, Start from frame {s} "
                        f"($21=${phase:02X}); one line per frame from power-on\n"
                        f"{time.strftime('%Y-%m-%d %H:%M')}")
        ram = replay(ROM, log)
        o = adapter.observe(_RamView(ram))
        v = adapter.judge(o, adapter.observe(_RamView(ram)))
        good = v.goal and o.state not in DEATH_STATES
        ok &= good
        print(f"replay from power-on, Start@{s}: {len(log)} frames total, {adapter.describe(o)}"
              f" -> {'GOAL' if good else 'NOT THE GOAL'}  [{path.name}]")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
