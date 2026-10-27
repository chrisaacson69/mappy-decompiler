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
# event -> the trigger voices its writer sets together (vars.toml snd_*: voice k = trigger $0600 + k)
EVENTS = {
    "voice_00": [0], "bonus_results": [1, 24], "extra_life": [2, 3, 4], "hurry": [5], "bonus_goal": [6],
    "drop": [7], "collect": [8], "door_wave": [9], "trampoline": [10], "death": [11, 12, 13],
    "bonus_intro": [14, 15, 16], "round_clear": [17, 18], "round_music": [19, 20], "game_over": [21, 22, 23],
}
TAIL, CAP = 120, 2700           # frames after the last value change; 45 s for the looping music


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


def capture(voice, frames=FRAMES):
    """-> [(frame, addr, value)]: frame 0 is the init, frames 1.. one update_sound_frame each. `voice`
    is one voice or a list triggered together."""
    bus = APULog(ROM)
    cpu = CPU6502(bus)
    call(cpu, SOUND_INIT)
    for v in (voice if isinstance(voice, list) else [voice]):
        bus.ram[TRIGGER + v] = 1
    for f in range(1, frames + 1):
        bus.frame = f
        call(cpu, SOUND_TICK)
    return bus.writes


def channel(addr):
    return CHANNELS.get(addr & ~3, "control") if addr < 0x4014 else "control"


def last_change(stream):
    img, last = {}, 0
    for f, a, v in stream:
        if f and img.get(a) != v:
            img[a], last = v, f
    return last


def render_events(out_dir):
    from emu_harness.machines.nes.apu import APU, FRAME_CYCLES, frames_to_cycles, write_wav
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, voices in EVENTS.items():
        stream = capture(voices, CAP)
        frames = min(last_change(stream) + TAIL, CAP)
        stream = [w for w in stream if w[0] <= frames]
        samples = APU().render(frames_to_cycles(stream), frames * FRAME_CYCLES / 1_789_773)
        write_wav(samples, out_dir / f"{name}.wav")
        print(f"{name:14s} voices {str(voices):14s} {frames / 60:5.1f} s  peak {samples.max():.2f}")


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
