"""Mappy adapter for emu-harness's segment search: play real rounds by search, headless Mesen.

The adapter is the game knowledge (RAM map, death, goal, objective, action space); the loop
is emu_harness.search.segment_search. The result is an input log from power-on, re-run in
a fresh instance with no savestates as the independent check.

RAM used (ch6 + measured 2026-10-02 by demo_in_real_game.py):
  $040F player state ($08 caught -> $2A -> $2C death anim), $70 p1 reserve lives,
  $7A round (0-based), $7B items left this round (10 on round 1), $71-$74 score (BCD, hi..lo),
  $42 demo flag (1 = real game).
  Items: 8-byte records at $0260, $81 bytes in all; +0 state (2 present, 4 being taken,
  0 gone), +4 horizontal position, +5 floor. Taken when +5 == player $0403 (floor) and
  |+4 - $0401| < 2 ($E660). Verified against the pickup frames of the demo replay.
Pad (read_and_decode_input $C1C9): only Left/Right (movement) and A/B (door action) matter.

  py -3.14 mappy/mappy_search.py [--rounds 1] [--workers 8] [--candidates 32] [--seg 96]
"""
from __future__ import annotations

import argparse
import hashlib
import sys
import time
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROM = HERE / "Mappy (Japan).nes"
sys.path.insert(0, str(HERE.parents[1] / "emu-harness"))
from emu_harness.machines.nes import KEYS, NES, write_input_log  # noqa: E402
from emu_harness.search import Verdict, segment_search  # noqa: E402

LEFT, RIGHT, A = (1 << KEYS.index(k) for k in ("left", "right", "a"))
P_X, P_Y, P_STATE, DEMO_FLAG = 0x400, 0x401, 0x40F, 0x42
LIVES, ROUND, ITEMS, SCORE = 0x70, 0x7A, 0x7B, slice(0x71, 0x75)
P_FLOOR, ITEM_TABLE, ITEM_BYTES = 0x403, 0x260, 0x81
FLOOR_COST = 40   # a floor change costs a trampoline trip; weight it like 40 columns
DEATH_STATES = {0x08, 0x2A, 0x2C}


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
    def __init__(self, seg_frames: int, target_round: int, shape: bool = False):
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
        return Verdict(score, dead=dead, goal=o.round >= self.target)

    def describe(self, o: Obs) -> str:
        return (f"round {o.round + 1} items left {o.items:>2} score {o.score:>7} "
                f"lives {o.lives} state ${o.state:02X} near {o.near:>3}")


def boot(rom: Path) -> tuple[str, list[int]]:
    """Power on, press Start on the title, run until the round-1 player is live."""
    with NES(rom) as m:
        m.step(frames=60)
        while m.ram(DEMO_FLAG)[0] != 1:
            m.step(["start"])
            m.step()
        while m.ram(P_STATE)[0] == 0:
            m.step()
        assert m.input_log_valid
        return m.save(), list(m.inputs)


def verify(rom: Path, log: list[int]) -> tuple[bytes, int]:
    """Independent check: replay the whole log from power-on in a fresh instance."""
    with NES(rom) as m:
        m.run_masks(log)
        return m.ram(0, 0x800), m.frame()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rounds", type=int, default=1, help="stop once this many rounds are cleared")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--candidates", type=int, default=32)
    ap.add_argument("--seg", type=int, default=96, help="frames per segment")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--minutes", type=float, default=30)
    ap.add_argument("--shape", action="store_true", help="score distance to the nearest item")
    a = ap.parse_args()
    out = HERE / "_scratch"
    out.mkdir(exist_ok=True)

    state, prefix = boot(ROM)
    print(f"booted: player live after {len(prefix)} frames")
    adapter = MappyAdapter(a.seg, a.rounds, a.shape)
    res = segment_search(lambda: NES(ROM, clean_battery=False), adapter, start_state=state,
                         start_log=prefix, candidates=a.candidates, workers=a.workers,
                         seed=a.seed, max_seconds=a.minutes * 60)
    final = res.checkpoints[-1]
    print(f"\n{'GOAL' if res.goal else 'stopped'}: {len(res.log)} frames "
          f"({len(res.log) / 60.0988:.1f} s of play), {res.candidates_run} candidates, "
          f"{res.backtracks} backtracks, {res.seconds:.0f}s wall")
    print("final:", adapter.describe(final.obs))

    tag = f"r{a.rounds}_s{a.seed}{'_shape' if a.shape else ''}"
    log_path = out / f"mappy_search_{tag}.txt"
    write_input_log(log_path, res.log, f"Mappy (Japan) segment search {tag}; one line per frame "
                    f"from power-on\n{time.strftime('%Y-%m-%d %H:%M')}")
    ram, frame = verify(ROM, res.log)
    o = adapter.observe(type("R", (), {"ram": lambda self, a, n: ram[a:a + n]})())
    print(f"replay from power-on: frame {frame}, {adapter.describe(o)}, ram sha1 "
          f"{hashlib.sha1(ram).hexdigest()[:12]}  ({'matches' if o == final.obs else 'DIFFERS FROM'} "
          f"the search's last checkpoint)")
    print("input log:", log_path)
    return 0 if res.goal else 1


if __name__ == "__main__":
    sys.exit(main())
