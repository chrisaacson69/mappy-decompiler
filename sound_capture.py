#!/usr/bin/env python3
"""
sound_capture.py - the Assets phase's sound lane, step 1: what each voice writes to the APU.

Runs Mappy's own sound engine headless, as rom_data.sound_reads does (init_apu_channels_and_frame_counter,
the trigger byte $0600+k = 1, then update_sound_frame once per frame), with only voice k triggered, and
records every write to $4000-$4017 with its frame. That register stream is all the APU ever sees, so it
is what a synthesizer plays and what Mesen's write-watch can check.

  py -3.14 mappy/sound_capture.py              -> per-voice summary (frames, writes, channels, loops?)
  py -3.14 mappy/sound_capture.py --json OUT   -> also the streams: {voice: [[frame, addr, value], ...]}
  py -3.14 mappy/sound_capture.py --wav DIR    -> one WAV per event (EVENTS: the voices the game triggers
                                                  together, from the snd_* trigger writers), played by
                                                  emu_harness.machines.nes.apu
"""
import json
import sys
from pathlib import Path

from emu_harness.cpu.m6502.cpu import CPU6502
from emu_harness.machines.nes.bus import Bus

HERE = Path(__file__).resolve().parent
ROM = (HERE / "Mappy (Japan).nes").read_bytes()
VOICES, SOUND_INIT, SOUND_TICK, TRIGGER = 25, 0xF4B5, 0xF4F1, 0x0600
FRAMES = 3600                   # 60 s: a voice still writing in its last 10 s is reported as looping
CHANNELS = {0x4000: "pulse1", 0x4004: "pulse2", 0x4008: "triangle", 0x400C: "noise", 0x4010: "dmc"}
# event -> (the trigger voices its writer sets together, how many frames the game keeps writing them).
# Voice k = trigger $0600 + k (vars.toml snd_*). The engine clears a trigger when its voice ends, so a
# held trigger restarts it: holds were measured from the game's own writes (sound_verify's Mesen watch:
# the door wave 119-148 frames, round music the whole round; HURRY 125 frames from the round-timer
# census). "loop" = held for good: rendered as two of the loops find_loop finds.
EVENTS = {
    "voice_00": ([0], 1), "bonus_results": ([1, 24], 1), "extra_life": ([2, 3, 4], 1), "hurry": ([5], 125),
    "bonus_goal": ([6], 1), "drop": ([7], 1), "collect": ([8], 1), "door_wave": ([9], 123),
    "trampoline": ([10], 1), "death": ([11, 12, 13], 1),
    # triggered once at the bonus intro; it runs 2,446 frames, the intro (210) plus the bonus limit (2,220)
    "bonus_round_music": ([14, 15, 16], 1),
    "round_clear": ([17, 18], 1), "round_music": ([19, 20], "loop"), "game_over": ([21, 22, 23], 1),
}
CAP = 4000                      # frames: longer than any one-shot here (bonus_round_music, 2,446)
LEAD, TAIL_S = 0.010, 0.3       # trim: seconds kept before the first and after the last sound


class APULog(Bus):
    """Bus that records every write to the APU registers, stamped with the current frame."""
    def __init__(self, rom):
        super().__init__(rom)
        self.frame = 0
        self.writes = []

    def write(self, addr, val):
        addr &= 0xFFFF
        if 0x4000 <= addr <= 0x4017 and addr not in (0x4014, 0x4016):
            self.writes.append((self.frame, addr, val & 0xFF))
        super().write(addr, val)


def call(cpu, entry):
    cpu.a, cpu.x, cpu.y, cpu.sp = 0, 0, 0, 0xFD
    cpu.push_word(0xFFFE)                       # RTS -> $FFFF
    cpu.pc = entry
    cpu.run_until({0xFFFF}, max_steps=2_000_000)


def capture(voice, frames=FRAMES, hold=1):
    """-> [(frame, addr, value)]: frame 0 is the init, frames 1.. one update_sound_frame each. `voice`
    is one voice or a list triggered together; the triggers are written before each of the first
    `hold` frames, as the game does for a held sound."""
    bus = APULog(ROM)
    cpu = CPU6502(bus)
    call(cpu, SOUND_INIT)
    voices = voice if isinstance(voice, list) else [voice]
    for f in range(1, frames + 1):
        if f <= hold:
            for v in voices:
                bus.ram[TRIGGER + v] = 1
        bus.frame = f
        call(cpu, SOUND_TICK)
    return bus.writes


def find_loop(stream, max_start=1500, max_period=4000):
    """-> (start, period) of the first frame range that repeats exactly (every APU write, in order), or None."""
    n = max(f for f, _, _ in stream)
    seq = [[] for _ in range(n + 1)]
    for f, a, v in stream:
        if f:
            seq[f].append((a, v))
    for period in range(120, max_period):
        for start in range(1, min(max_start, n - 2 * period)):
            if all(seq[f] == seq[f + period] for f in range(start, start + period)):
                return start, period
    return None


def channel(addr):
    return CHANNELS.get(addr & ~3, "control") if addr < 0x4014 else "control"


def last_change(stream):
    img, last = {}, 0
    for f, a, v in stream:
        if f and img.get(a) != v:
            img[a], last = v, f
    return last


def render_events(out_dir):
    import numpy as np
    from emu_harness.machines.nes.apu import APU, CPU_HZ, FRAME_CYCLES, RATE, frames_to_cycles, write_wav
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, (voices, hold) in EVENTS.items():
        if hold == "loop":
            stream = capture(voices, 8000, hold=8000)
            start, period = find_loop(stream)
            frames, note = start + 2 * period, f"loop of {period} frames ({period * FRAME_CYCLES / CPU_HZ:.2f} s) from frame {start}, x2"
        else:
            stream = capture(voices, CAP, hold=hold)
            frames, note = min(last_change(stream) + 60, CAP), f"held {hold} frame(s)"
        stream = [w for w in stream if w[0] <= frames]
        x = APU().render(frames_to_cycles(stream), frames * FRAME_CYCLES / CPU_HZ)
        live = np.flatnonzero(np.abs(np.diff(x)) > 1e-6)                # the samples where anything sounds
        a = max(0, live[0] - int(LEAD * RATE))
        b = len(x) if hold == "loop" else min(len(x), live[-1] + int(TAIL_S * RATE))
        gain = write_wav(x[a:b], out_dir / f"{name}.wav", peak=0.89)   # -1 dBFS
        print(f"{name:18s} voices {str(voices):13s} {(b - a) / RATE:5.2f} s  gain x{gain / 0.9:4.1f}  {note}")


def main():
    if "--wav" in sys.argv:
        render_events(Path(sys.argv[sys.argv.index("--wav") + 1]))
        return
    streams = {}
    print(f"{'voice':>5}  {'writes':>6}  {'first':>5}  {'last':>5}  loops  channels")
    for v in range(VOICES):
        w = [x for x in capture(v) if x[0] > 0]          # frame 0 is the shared init
        streams[v] = w
        if not w:
            print(f"{v:5d}  {0:6d}      -      -    -    (silent)")
            continue
        last = w[-1][0]
        chans = sorted({channel(a) for _, a, _ in w})
        print(f"{v:5d}  {len(w):6d}  {w[0][0]:5d}  {last:5d}  {'yes' if last > FRAMES - 600 else ' no'}    {', '.join(chans)}")
    if "--json" in sys.argv:
        out = Path(sys.argv[sys.argv.index("--json") + 1])
        out.write_text(json.dumps({v: [list(x) for x in s] for v, s in streams.items()}), encoding="utf-8")
        print("wrote", out)


if __name__ == "__main__":
    main()
