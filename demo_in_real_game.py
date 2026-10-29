"""Feed Mappy's attract-mode input script ($FFE1) into a real game through the pad, headless Mesen.

Step 1 of the Mappy search harness (vault: research/gaming/zelda-ai-speedrun-harness.md).

  1. Reference: power on, no input, trace RAM every frame through attract mode. The frame
     the demo reads script byte 0 is flagged by a read of $FFE1.
  2. Real game: power on, press Start on the title, trace RAM. Find the frame the round's
     player becomes active ($040F leaves 0) and play the script from there, translated to
     pad input, with a sweep of start offsets.
  3. Compare the player's x / y / movement / state per frame against the reference and
     report the first divergence, and what the round did (cleared, died).

Script byte -> pad (ch6, verified 2026-10-02): bits 7-6 = 11 Left, 10 Right, 01 action,
00 stop; length (b & $3F) * 4 + 1 frames. Real play writes $26 (Left->$FF, Right->$01,
both/neither->$00) into movement $040D every frame, and $22 (an "A or B pressed" shift
register) into $040E; the demo's `inc $040E` pulse equals a one-frame A press. An action
command does not touch movement, so the previous direction stays held.

  py -3.14 mappy/demo_in_real_game.py [--offsets -2 -1 0 1 2] [--bytes 25]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from paths import ROM, TRACES
from emu_harness.backends.mesen import read_trace as _read_trace
from emu_harness.machines.nes import NES

SCRIPT_ADDR = 0xFFE1
SCRIPT_LEN = 25
RAM = 0x800
# player record (object 0) fields, ch2/ch6
P_X, P_Y, P_MOVE, P_ACT, P_STATE = 0x400, 0x401, 0x40D, 0x40E, 0x40F
DEMO_FLAG, STAGE_END_A, STAGE_END_B, CURSOR, LIVES, ROUND = 0x42, 0x4F, 0x4B, 0x3D, 0x70, 0x7A
SCORE = (0x71, 0x72, 0x73, 0x74)  # p1 score bytes (BCD) -- see vars.toml; printed raw


def read_trace(path: Path) -> list[tuple[int, bytes]]:
    return _read_trace(path, RAM)


def script_bytes(m: NES, count: int) -> list[int]:
    return list(m.ram(SCRIPT_ADDR, count))


def script_to_pad(script: list[int]) -> list[list[str]]:
    """One list of pad names per frame."""
    frames, held = [], []
    for b in script:
        n = (b & 0x3F) * 4 + 1
        kind = b >> 6
        if b == 0:
            break                       # a whole $00 stops the demo for good
        if kind == 3:
            held = ["Left"]
        elif kind == 2:
            held = ["Right"]
        elif kind == 0:
            held = []
        if kind == 1:
            frames.append(held + ["A"])
            frames += [list(held)] * (n - 1)
        else:
            frames += [list(held)] * n
    return frames


def player(ram: bytes) -> tuple[int, int, int, int]:
    return ram[P_X], ram[P_Y], ram[P_MOVE], ram[P_STATE]


def reference(scratch: Path, frames: int) -> tuple[list[tuple[int, bytes]], int, list[int]]:
    path = scratch / "mappy_attract.trace"
    with NES(ROM) as m:
        script = script_bytes(m, SCRIPT_LEN)
        m.trace("nesDebug", 0, RAM, path.resolve(), flag_addr=SCRIPT_ADDR)
        m.step(frames=frames)
        m.trace_off()
    tr = read_trace(path)
    first = next(i for i, (flag, _) in enumerate(tr) if flag)
    return tr, first, script


def start_game(m: NES, max_frames: int = 3000) -> int:
    """Press Start (one frame on, one off) until the demo flag $42 reads 1. Returns frames used."""
    m.step(frames=60)
    for _ in range(max_frames // 2):
        m.step(["start"])
        m.step()
        if m.ram(DEMO_FLAG)[0] == 1:
            return m.frame()
    raise RuntimeError("Start never took ($42 stayed 0)")


def real_game(scratch: Path, pad: list[list[str]], lead: int, tail: int, tag: str):
    """Start a game, wait for the player to go active, idle `lead` frames, play `pad`."""
    path = scratch / f"mappy_real_{tag}.trace"
    with NES(ROM) as m:
        m.trace("nesDebug", 0, RAM, path.resolve())
        start_frame = start_game(m)
        # wait for the round's player: state goes 0 during the intro, nonzero when live
        waited = 0
        while m.ram(P_STATE)[0] == 0 or m.ram(DEMO_FLAG)[0] != 1:
            m.step()
            waited += 1
            if waited > 3000:
                raise RuntimeError("player never went active")
        # if the state was already nonzero right after Start, wait for a 0 -> nonzero edge
        active_frame = m.frame()
        if lead > 0:
            m.step(frames=lead)
        masks = [m.mask_from_names(f) for f in pad] + [0] * tail
        m.run_masks(masks)
        m.trace_off()
    return read_trace(path), start_frame, active_frame


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bytes", type=int, default=SCRIPT_LEN, help="script bytes to play")
    ap.add_argument("--offsets", type=int, nargs="*", default=None,
                    help="extra frames to idle after the player goes active (default: derived)")
    ap.add_argument("--tail", type=int, default=600, help="idle frames after the script")
    a = ap.parse_args()
    scratch = TRACES
    scratch.mkdir(exist_ok=True)

    ref, first, script = reference(scratch, 6000)
    print("script:", " ".join(f"{b:02X}" for b in script))
    # reference: first frame the player record is live, and lead from there to byte 0's read
    ref_active = next(i for i in range(first, -1, -1) if ref[i][1][P_STATE] == 0) + 1
    ref_lead = first - ref_active
    print(f"attract: player live at trace frame {ref_active}, script byte 0 read at {first} "
          f"(lead {ref_lead}); player at byte 0: x,y,move,state = {player(ref[first][1])}")
    ref_end = next((i for i in range(first, len(ref))
                    if ref[i][1][STAGE_END_A] | ref[i][1][STAGE_END_B]), None)
    print(f"attract: stage-end flag ($4F|$4B) at trace frame {ref_end} "
          f"({None if ref_end is None else ref_end - first} frames into the script)")

    pad = script_to_pad(script[:a.bytes])
    offsets = a.offsets if a.offsets is not None else [ref_lead + d for d in (-2, -1, 0, 1, 2)]
    for lead in offsets:
        tr, start_frame, active_frame = real_game(scratch, pad, lead, a.tail, f"lead{lead}")
        # trace index i = end of frame i+1 since power-on (trace started at frame 0).
        # Align the two timelines on "player went live": real index active_frame-1 <-> ref_active.
        # k counts frames from the reference's script byte 0.
        base = active_frame - 1 - ref_active
        go = active_frame + lead          # trace index of the first scripted pad frame
        diverge = None
        for k in range(min(len(pad), len(ref) - first, len(tr) - first - base)):
            if player(tr[first + base + k][1]) != player(ref[first + k][1]):
                diverge = k
                break
        end = next((i - go for i in range(go, len(tr))
                    if tr[i][1][STAGE_END_A] | tr[i][1][STAGE_END_B]), None)
        died = next((i - go for i in range(go, len(tr)) if tr[i][1][P_STATE] == 0x2C), None)
        last = tr[-1][1]
        print(f"lead {lead:>4}: start@{start_frame} live@{active_frame} | first divergence "
              f"from attract at script frame {diverge} | stage-end at {end} | death (state $2C) at "
              f"{died} | end: lives={last[LIVES]} round={last[ROUND]} state=${last[P_STATE]:02X}")
        if diverge is not None:
            lo = max(0, diverge - 3)
            for k in range(lo, diverge + 4):
                if first + base + k < len(tr) and first + k < len(ref):
                    print(f"      k={k:>5} real {player(tr[first + base + k][1])}  "
                          f"attract {player(ref[first + k][1])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
