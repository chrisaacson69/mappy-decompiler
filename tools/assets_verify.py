#!/usr/bin/env python3
"""
assets_verify.py - the Assets gate's live checks: the graphics data and the renderer against Mesen.

At a frame after a round has loaded (default: round 1 of the tas60 log, before anything moves):
  1. DATA. The live nametables and palette RAM (PPUSnapshot) against the same round loaded headless by
     the game's own routines: build_stage_screen_layout, load_round_trampolines, load_round_items,
     load_round_doors, spawn_floor_traps, load_bells, with rendering off and the live RAM as the
     starting state (so the HUD numbers agree), then the per-frame drawers (update_doors' wave doors
     or update_balloons, and the 1UP label) for the last 16 frame-counter values, so their phase is
     the live one. A bonus round takes next_round's bonus branch.
     Every nametable byte and palette entry is compared.
  2. RENDERER. Mesen's own screenshot of that frame against the library's rebuild of it from the
     live VRAM, OAM and scroll (PPUSnapshot.frame). The two palettes differ in RGB, so the test is that
     colours map one to one, pixel for pixel, on every row. The HUD is a timed split: scroll 0 is
     written in vblank ($C1A7) and the camera scroll mid-frame ($C092); the split scanline is measured
     on Mesen (the store's cycle distance from the NMI) and handed to the library as a split.

  py -3.14 mappy/assets_verify.py [--log L] [--frame F] [--poke F:AA=VV ...] [--renderer-only]
  py -3.14 mappy/assets_verify.py --suite     the gate: every SUITE run exact, and a planted fault (one
                                              picture byte changed in the headless ROM) caught
"""
import argparse
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image

from emu_harness.backends.mesen.client import read_watch
from emu_harness.cpu.m6502.cpu import CPU6502
from emu_harness.machines.nes import NES, ppu, read_input_log
from emu_harness.machines.nes.bus import Bus
from emu_harness.machines.nes.live import PPUSnapshot
from emu_harness.machines.nes.ppuport import PPUPort

from paths import ROM, TRACES
# the round load, in next_round's order: layout, trampolines, then (is_bonus_round, $7C) items, doors,
# floor traps, bells, or stage params and balloons
LOADERS = {False: [0xCD49, 0xE35B, 0xE5C5, 0xE862, 0xF001, 0xEF17], True: [0xCD49, 0xE35B, 0xF3C1, 0xF13A]}
IS_BONUS = 0x7C
ATTR_FLUSH = 0xC7C9                                       # flush_dirty_attribute_bytes, every render-loop frame
TITLE_BLOCK, BLINK_UP, FLUSH = 0xCC15, 0xD71C, 0xC150     # the title's draw block (the sprite palette's only
                                                          # writer), the 1UP label, the render thread's
                                                          # $0500 queue flush (the HUD numbers go through it)
# the per-frame drawers among update_round_frame's / update_bonus_round_frame's calls: update_doors (one
# door per frame, slot fc & 3: wave doors blink), update_balloons (each balloon's animation frame), the
# 1UP label. The rest move objects or score, which the live RAM already holds
PER_FRAME = {False: [0xE8CC, BLINK_UP], True: [0xF18F, BLINK_UP]}
CAMERA_STORE, NMI = 0xC095, 0xC2EF                        # just after render_loop's camera PPUSCROLL; nmi entry
FRAME_COUNTER = 0x21
YIELD = 0xC141                                            # yield_to_render_loop: the thread switch
FAULT = (0xEC96, 0x52, 0x53)                              # the wave-door blink picture's first tile, 52 -> 53


def call(cpu, entry, y=0):
    # the game thread's stack (game_thread_task's slot $3F): build_stage_screen_layout fills $0170-$01FF
    # (the attribute work area shares the stack page above that stack), so a stack at $FD is clobbered
    cpu.a, cpu.x, cpu.y, cpu.sp = 0, 0, y, 0x3F
    cpu.push_word(0xFFFE)
    cpu.pc = entry
    cpu.run_until({0xFFFF}, max_steps=5_000_000)
    assert cpu.pc == 0xFFFF, f"${entry:04X} did not return (pc ${cpu.pc:04X})"


def live(log, frame, pokes):
    shot = (TRACES / "assets_verify_shot.png").resolve()
    watches = {k: (TRACES / f"av_{k}.watch").resolve() for k in ("store", "nmi")}
    with NES(ROM) as m:
        masks = [m.mask_from_names(f) for f in read_input_log(log)]
        done = 0
        for f, a, v in sorted(p for p in pokes if p[0] < frame - 1):
            m.run_masks(masks[done:f]); m.write("nesDebug", a, bytes([v])); done = f
        m.run_masks(masks[done:frame - 1])
        m.watch("exec", CAMERA_STORE, CAMERA_STORE, watches["store"], regs=True)
        m.watch("exec", NMI, NMI, watches["nmi"], regs=True)
        m.run_masks(masks[frame - 1:frame])
        m.watch_off()
        snap = PPUSnapshot.capture(m)
        ram = m.read("nesDebug", 0, 0x800)
        m.screenshot(shot)
    return snap, ram, Image.open(shot).convert("RGB"), split_scanline(*(read_watch(watches[k]) for k in ("store", "nmi")))


def split_scanline(stores, nmis):
    """The first scanline drawn with the camera scroll. NTSC: the NMI lands at scanline 241, then 21
    lines of 341 dots (241-260 and the pre-render line) before line 0, 3 dots per CPU cycle; a
    $2005 write reaches the next line at its dot-257 horizontal copy."""
    c = stores[-1]["cpu.cycleCount"]
    n = max(r["cpu.cycleCount"] for r in nmis if r["cpu.cycleCount"] < c)
    dots = (c - n) * 3
    line, dot = dots // 341 - 21, dots % 341
    return line + (1 if dot < 257 else 2)


def headless(ram, fault=False):
    # the render thread's work is the explicit ATTR_FLUSH / FLUSH calls below, so in this copy of the ROM
    # a yield returns at once (build_stage_screen_layout waits 210 frames on it for the bonus intro card,
    # then clears the screen and draws the round)
    rom = bytearray(ROM.read_bytes())
    rom[16 + YIELD - 0xC000] = 0x60                     # rts
    if fault:
        assert rom[16 + FAULT[0] - 0xC000] == FAULT[1], "the fault site moved"
        rom[16 + FAULT[0] - 0xC000] = FAULT[2]
    port = PPUPort()
    bus = Bus(bytes(rom), ppu=port)
    bus.ram[:] = ram
    bus.ram[0x2D] = 0                                   # rendering off: the loaders write straight to VRAM
    cpu = CPU6502(bus)
    call(cpu, TITLE_BLOCK, y=2)                         # what the title drew before the round (the palettes)
    bus.ram[0x2A] = bus.ram[0x2B] = 0                   # empty queues, as after the title's last flush
    bonus = bool(ram[IS_BONUS])
    for entry in LOADERS[bonus]:
        call(cpu, entry)
    # the blinkers' last 16 frames, each one flushed. The game thread's last pass saw fc - 1 (the counter
    # steps after it; Mesen exec watch on update_doors), and that pass's queue is only written out at the
    # next vblank, so the VRAM in the snapshot holds the passes through fc - 2
    fc = ram[FRAME_COUNTER]
    for f in range(fc - 17, fc - 1):
        bus.ram[FRAME_COUNTER] = f & 0xFF
        for entry in PER_FRAME[bonus]:
            call(cpu, entry)
        call(cpu, ATTR_FLUSH)                           # the render loop's attribute pass (render still off)
        call(cpu, FLUSH)                                # the render thread writes the $0500 queue out
    return port


def poke(s):
    f, rest = s.split(":")
    a, v = rest.split("=")
    return int(f), int(a, 16), int(v, 16)


# (input log, pokes, snapshot frame, data check?, what): each round type just after its load (round 1 loads
# at frame 61, a poked round at 3712, the bonus branch at 3927; Mesen exec watches on $CD49 / $C9CF), and
# one frame with the camera moved, renderer only (by then the round has changed from its load)
SUITE = [
    ("mappy_tas60_start60.txt", [], 130, True, "round 1"),
    ("mappy_bonus_lr12.txt", ["130:7A=06"], 3781, True, "round 8 (bells)"),
    ("mappy_bonus_lr12.txt", ["130:7A=0A"], 3781, True, "round 12 (floor traps)"),
    # a bonus round moves at once: 3946 is the frame after the balloons finish drawing (3945 still
    # drawing) and before Mappy's first landing flexes a trampoline (3947)
    ("mappy_bonus_lr40.txt", ["130:7A=01"], 3946, True, "bonus round 3"),
    ("mappy_tas60_start60.txt", [], 400, False, "round 1, the camera moved"),
]


def check(log, frame, pokes, data=True, label="", fault=False):
    snap, ram, shot, split = live(log, frame, pokes)
    ok = True

    # 1. data: the two pages Mappy uses ($2000, $2400; vertical mirroring) and the palette RAM
    if data:
        port = headless(ram, fault)
        diff = [(0x2000 + i, port.vram[0x2000 + i], snap.nametables[i]) for i in range(0x800)
                if port.vram[0x2000 + i] != snap.nametables[i]]
        pal_diff = [(i, port.vram[0x3F00 + i], snap.palette[i]) for i in range(32)
                    if (port.vram[0x3F00 + i] & 0x3F) != (snap.palette[i] & 0x3F) and i % 4]   # $3F10/$14/.. mirror
        print(f"{label}[data] nametables: {0x800 - len(diff):,} of 2,048 bytes identical; palette: {32 - len(pal_diff)} of 32")
        for a_, h, l in diff[:12]:
            print(f"    ${a_:04X}: headless {h:02X}  live {l:02X}")
        ok = not diff and not pal_diff

    # 2. renderer: Mesen's frame vs the library's rebuild of the live state, colour for colour
    lib = snap.frame(master=ppu.NES_MASTER_FCEUX, origin=(0, 0), splits=[(split, snap.scroll())])
    if shot.size != lib.size:
        print(f"{label}[renderer] sizes differ: Mesen {shot.size}, library {lib.size}")
        return False
    S, L = shot.load(), lib.load()
    rows_ok, fwd, back = [], defaultdict(set), defaultdict(set)
    for y in range(240):
        f2, b2 = defaultdict(set), defaultdict(set)
        for x in range(256):
            f2[L[x, y]].add(S[x, y]); b2[S[x, y]].add(L[x, y])
        if all(len(v) == 1 for v in f2.values()) and all(len(v) == 1 for v in b2.values()):
            rows_ok.append(y)
            for k, v in f2.items():
                fwd[k] |= v
            for k, v in b2.items():
                back[k] |= v
    one_to_one = all(len(v) == 1 for v in fwd.values()) and all(len(v) == 1 for v in back.values())
    bad = [y for y in range(240) if y not in rows_ok]
    runs = []
    for y in bad:
        if runs and y == runs[-1][1] + 1:
            runs[-1][1] = y
        else:
            runs.append([y, y])
    print(f"{label}[renderer] HUD split at scanline {split}, camera {snap.scroll()}; rows where the colours map one to"
          f" one: {len(rows_ok)} of 240 (consistent across them: {one_to_one}); other rows:"
          f" {', '.join(f'{a}-{b}' for a, b in runs) or 'none'}")
    lib.save(TRACES / "assets_verify_library.png")
    return ok and one_to_one and not bad


def main():
    if "--suite" in sys.argv:
        results = [check(TRACES / log, frame, [poke(p) for p in pokes], data, f"[{what}] ")
                   for log, pokes, frame, data, what in SUITE]
        caught = not check(TRACES / SUITE[0][0], SUITE[0][2], [], True, "[planted fault: blink tile 52 -> 53] ", True)
        print(f"suite: {sum(results)} of {len(results)} exact; planted fault {'caught' if caught else 'NOT CAUGHT'}")
        return 0 if all(results) and caught else 1
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", type=Path, default=TRACES / "mappy_tas60_start60.txt")
    ap.add_argument("--frame", type=int, default=130)
    ap.add_argument("--poke", type=poke, action="append", default=[])
    ap.add_argument("--renderer-only", action="store_true")
    a = ap.parse_args()
    return 0 if check(a.log, a.frame, a.poke, not a.renderer_only) else 1


if __name__ == "__main__":
    sys.exit(main())
