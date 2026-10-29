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
  beam search:         add --beam 8 [--per-node 8]
"""
from __future__ import annotations

import argparse
import sys
import time
from dataclasses import dataclass
from pathlib import Path

from paths import ROM, TRACES
from emu_harness.machines.nes import KEYS, NES, write_input_log  # pip install -e ../emu-harness
from emu_harness.search import Searcher, Verdict

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
    left: int = 0   # bitmask of items still present (bit i = record i)
    floor: int = 0  # player floor ($0403)


def bcd(b: bytes) -> int:
    return int(b.hex())


class MappyAdapter:
    def __init__(self, seg_frames: int, target_round: int, shape: bool = True,
                 route: list[int] | None = None):
        self.seg = seg_frames
        self.target = target_round
        self.shape = shape
        self.route = route      # item order to follow (record indices); None = nearest first

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
        present = [k for k in range(r[ITEM_BYTES] // 8) if r[ITEM_TABLE + 8 * k] == 2]
        if self.route and r[ROUND] == 0:
            # aim at the first item of the route still present (round 1 only, for now)
            nxt = next((k for k in self.route if k in present), None)
            present = [nxt] if nxt is not None else present
        d = [abs(r[ITEM_TABLE + 8 * k + 4] - px) + FLOOR_COST * abs(r[ITEM_TABLE + 8 * k + 5] - pf) // 4
             for k in present]
        left = sum(1 << (k // 8) for k in range(0, r[ITEM_BYTES], 8) if r[ITEM_TABLE + k] == 2)
        return Obs(r[P_STATE], r[LIVES], r[ROUND], r[ITEMS], bcd(r[SCORE]), r[P_X], r[P_Y],
                   min(d, default=0), left, r[P_FLOOR])

    def key(self, o: Obs):
        """Beam diversity: one line per (which items remain, floor), so different item
        orders survive side by side instead of all following the greedy nearest-item route."""
        return (o.round, o.left, o.floor)

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


def tour(items: list[tuple[int, int]], start: tuple[int, int], floor_cost: float,
         noise: list[list[float]] | None = None) -> list[int]:
    """Shortest open tour from `start` through every item (Held-Karp; 10 items is trivial)
    under cost |dpos| + floor_cost * floors (+ optional per-edge noise)."""
    n = len(items)
    pts = [start] + items

    def c(a, b):
        (x1, f1), (x2, f2) = pts[a], pts[b]
        v = abs(x1 - x2) + floor_cost * abs(f1 - f2) / 4
        return v + (noise[a][b] if noise else 0)

    best = {(1 << i, i): (c(0, i + 1), None) for i in range(n)}
    for mask in range(1, 1 << n):
        for i in range(n):
            if (mask, i) not in best:
                continue
            base = best[(mask, i)][0]
            for j in range(n):
                if mask >> j & 1:
                    continue
                key = (mask | 1 << j, j)
                v = base + c(i + 1, j + 1)
                if key not in best or v < best[key][0]:
                    best[key] = (v, i)
    full = (1 << n) - 1
    i = min(range(n), key=lambda i: best[(full, i)][0])
    order, mask = [], full
    while i is not None:
        order.append(i)
        prev = best[(mask, i)][1]
        mask &= ~(1 << i)
        i = prev
    return order[::-1]


def routes_for(ram: bytes, count: int, seed: int) -> list[list[int]]:
    """Distinct candidate item orders: exact tours over a sweep of floor costs, then
    noisy variants, until `count` distinct routes."""
    import random
    n = ram[ITEM_BYTES] // 8
    items = [(ram[ITEM_TABLE + 8 * k + 4], ram[ITEM_TABLE + 8 * k + 5]) for k in range(n)]
    start = (ram[P_Y], ram[P_FLOOR])
    out: list[list[int]] = []
    for fc in (10, 20, 40, 80, 120):
        r = tour(items, start, fc)
        if r not in out:
            out.append(r)
    rng = random.Random(seed)
    tries = 0
    while len(out) < count and tries < 200:
        tries += 1
        fc = rng.choice((10, 20, 40, 80, 120))
        noise = [[rng.uniform(0, 30) for _ in range(n + 1)] for _ in range(n + 1)]
        r = tour(items, start, fc, noise)
        if r not in out:
            out.append(r)
    return out[:count]


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
    ap.add_argument("--beam", type=int, default=0, help="beam width (0 = greedy segment search)")
    ap.add_argument("--per-node", type=int, default=8, help="beam: candidates per node")
    ap.add_argument("--routes", type=int, default=0,
                    help="plan N distinct item orders and search each (round 1); 0 = nearest first")
    ap.add_argument("--tag", default="")
    a = ap.parse_args()
    out = TRACES
    out.mkdir(exist_ok=True)

    boots = [boot(ROM, s) for s in a.starts]
    for s, (_, prefix, phase) in zip(a.starts, boots):
        print(f"seed: Start from frame {s}: live after {len(prefix)} frames, $21 = ${phase:02X}")
    adapter = MappyAdapter(a.seg, a.rounds, a.shape)
    best = None
    best_route = None
    if a.routes:
        with NES(ROM) as m:
            m.load(boots[0][0])
            ram0 = m.ram(0, 0x800)
        plans = routes_for(ram0, a.routes, a.seed)
    else:
        plans = [None]
    with Searcher(lambda: NES(ROM, clean_battery=False), adapter, workers=a.workers) as srch:
        for route in plans:
            adapter.route = route
            if route:
                print(f"\n#### route {'-'.join(map(str, route))}")
            for k in range(a.restarts):
                sd = a.seed + k
                print(f"\n== search seed {sd}" + (f", to beat {best.goal_frame} frames" if best else ""))
                bound = best.goal_frame if best else None
                if a.beam:
                    res = srch.beam_search([b[0] for b in boots], width=a.beam, per_node=a.per_node,
                                           seed=sd, max_seconds=a.minutes * 60, bound=bound)
                else:
                    res = srch.search([b[0] for b in boots], candidates=a.candidates, seed=sd,
                                      max_seconds=a.minutes * 60, bound=bound)
                verdict = (f"GOAL in {res.goal_frame} frames ({res.goal_frame / 60.0988:.2f} s)"
                           if res.goal else ("pruned" if res.pruned else "stopped"))
                print(f"-- {verdict}; {res.candidates_run} runs, {res.backtracks} backtracks, "
                      f"{res.seconds:.0f}s wall")
                if res.goal and (best is None or res.goal_frame < best.goal_frame):
                    best, best_route = res, route
    if best_route:
        print(f"\nbest route: {'-'.join(map(str, best_route))}")
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
