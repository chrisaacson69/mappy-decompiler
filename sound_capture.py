#!/usr/bin/env python3
"""
sound_capture.py - Mappy's adapter for the emu-harness sound lane (emu_harness.machines.nes.sound).

Runs Mappy's own sound engine headless, as rom_data.sound_reads does (init_apu_channels_and_frame_counter,
the trigger byte $0600+k = 1, then update_sound_frame once per frame), and the library records every
write to $4000-$4017 with its frame. That register stream is all the APU ever sees, so it is what a
synthesizer plays and what Mesen's write-watch can check (sound_verify.py). The capture, loop search
and WAV rendering were this file's own until 2026-10-29; they moved into the library, which NA1 uses too.

  py -3.14 sound_capture.py              -> per-voice summary (frames, writes, channels, loops?)
  py -3.14 sound_capture.py --json OUT   -> also the streams: {voice: [[frame, addr, value], ...]}
  py -3.14 sound_capture.py --wav DIR    -> one WAV per event (EVENTS: the voices the game triggers
                                            together, from the snd_* trigger writers)
  (the same: py -3.14 -m emu_harness.machines.nes.sound sound_capture.py --wav DIR)
"""
import json
import sys
from pathlib import Path

from emu_harness.cpu.m6502.cpu import CPU6502
from emu_harness.machines.nes import sound
from emu_harness.machines.nes.bus import Bus

HERE = Path(__file__).resolve().parent
ROM = (HERE / "Mappy (Japan).nes").read_bytes()
VOICES, SOUND_INIT, SOUND_TICK, TRIGGER = 25, 0xF4B5, 0xF4F1, 0x0600
FRAMES = 3600                   # 60 s: a voice still writing in its last 10 s is reported as looping
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
CAP = sound.CAP


def call(cpu, entry):
    cpu.a, cpu.x, cpu.y, cpu.sp = 0, 0, 0, 0xFD
    cpu.push_word(0xFFFE)                       # RTS -> $FFFF
    cpu.pc = entry
    cpu.run_until({0xFFFF}, max_steps=2_000_000)


class Engine:
    """The library's adapter contract (emu_harness.machines.nes.sound): a request is a list of voices,
    triggered together by setting $0600 + k = 1."""
    events = EVENTS

    def machine(self):
        self.bus = Bus(ROM)
        self.cpu = CPU6502(self.bus)
        return self.bus

    def init(self):
        call(self.cpu, SOUND_INIT)

    def request(self, voices):
        for v in voices if isinstance(voices, list) else [voices]:
            self.bus.ram[TRIGGER + v] = 1

    def tick(self):
        call(self.cpu, SOUND_TICK)


def capture(voice, frames=FRAMES, hold=1):
    """-> [(frame, addr, value)]: frame 0 is the init, frames 1.. one update_sound_frame each."""
    return sound.capture(Engine(), voice, frames, hold)


def main():
    if "--wav" in sys.argv:
        return sound.main([__file__, "--wav", sys.argv[sys.argv.index("--wav") + 1]])
    streams = {}
    print(f"{'voice':>5}  {'writes':>6}  {'first':>5}  {'last':>5}  loops  channels")
    for v in range(VOICES):
        w = [x for x in capture(v) if x[0] > 0]          # frame 0 is the shared init
        streams[v] = w
        if not w:
            print(f"{v:5d}  {0:6d}      -      -    -    (silent)")
            continue
        last = w[-1][0]
        chans = sorted({sound.channel(a) for _, a, _ in w})
        print(f"{v:5d}  {len(w):6d}  {w[0][0]:5d}  {last:5d}  {'yes' if last > FRAMES - 600 else ' no'}    {', '.join(chans)}")
    if "--json" in sys.argv:
        out = Path(sys.argv[sys.argv.index("--json") + 1])
        out.write_text(json.dumps({v: [list(x) for x in s] for v, s in streams.items()}), encoding="utf-8")
        print("wrote", out)


if __name__ == "__main__":
    main()
