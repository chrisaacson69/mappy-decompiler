---
status: active
created: 2026-10-27
---
# Mappy — Chapter 10: The Build-Tool Pass

> Chapter 9 re-derived Mappy from the bare binary. This chapter ran that work again through
> emu-harness's phase-gated build tool (classify → recon → discover → data → structure → naming →
> presentation → assets → live). Each phase ends on a gate that can fail, and a planted fault has to
> fail it. All nine gates pass. The result is a listing whose names, data, pictures, sounds and
> per-frame behaviour have each been checked against something lower than the listing itself.

**Links:** [Mappy README](./README.md), [Ch9: From-Scratch Re-Derivation](./09-from-scratch-rederivation.md), [Open threads](./NOTES-open-threads.md), status: `py -3.14 -m emu_harness status game-annotation/mappy` (reads `re-roadmap.toml`; every gate's numbers are there)

## What each gate rests on

| Phase | Checked against | Result |
|---|---|---|
| discover | a Mesen code/data log over ~15,000 frames of real play (`cdl_gap.py`) | 0 executed bytes the listing fails to decode (was 63, `$EA51-$EA8F`); code recall vs the published disassembly 10,754 / 10,754, graded after the fact and never used as an input |
| structure | Chris's hand-drawn tree from RESET / NMI / IRQ | 280 / 280 routines reached through 542 typed edges |
| naming | each routine's bytes, plus runs on the emulator (`state_census.py`) | 473 labels (182 routines, 98 leaves, 3 dead, 190 data), 210 variables, one 16-field record template; graded after naming against the published state comments: 13 / 13 normal, 10 / 10 bonus |
| assets: sound | Mesen's own APU writes during play (`sound_verify.py`) | 14,045 writes identical over 5,032 frames |
| assets: pictures | live VRAM and palette right after a load, plus Mesen's screenshot (`assets_verify.py --suite`) | rounds 1, 8, 12 and bonus round 3: 2,048 / 2,048 nametable bytes, 32 / 32 palette entries, 240 / 240 rows pixel for pixel; a one-byte picture fault is caught |
| live | the game's own per-object step, run headless over live RAM at every step (`live_verify.py --suite`) | 425,547 steps identical over 10 runs, every reachable state seen; a one-instruction fault (`walk_step` +1 → +2) is caught on 6,431 steps |

## Corrections to the earlier chapters

- **Ch7 / Ch9: there is no "object animation VM."** `$F606` is the **sound engine's voice-stream
  interpreter** (`run_voice_stream`). Its `$E8-$F9` opcodes are the 18 sound ops (`voice_op_end`,
  `_set_duty`, `_set_envelope`, ...). Every stream ends in `$E8` or `$F9`, and the register images
  match Mesen. Chapter 9 read the 25 voices as objects.
- **Ch8 / Ch9: the "blinking platforms" are floor traps,** in rounds 12-14 (`spawn_floor_traps`
  `$F001`, `update_floor_traps` `$F04D`).
- **Ch2 / Ch9: the record's fields.** These were settled by code and by the attract demo:
  - `+4` is `obj_anim` (the draw index), not a state.
  - `+5` is `obj_type` (0 Mappy, 1 the coin, 2 Goro, 3 the Meowkies), as Chapter 2 said.
  - `+6` is `obj_dir`.
  - `+8` is `obj_tile`: the tile under the object, read back from VRAM.
  - `+B` is `obj_vy_or_link`: the hop velocity, the trampoline index, or the wave carrying a cat. That polymorphism now has one honest name.
  - `+E` is `obj_buttons`: the A/B history copied in from `$22`.
- **Ch6 / open threads: `$21` is the frame counter, and the cats' coin flips are read from the
  copyright text.** `choose_cat_target_floor` takes bit 0 of the byte at `$C000 + frame_counter`,
  inside `COPYRIGHT 1983 1984 NAMCO LTD.` So the "hidden seed" that `seed_test.py` measured is
  that one-byte phase.
- **Open threads: `$7B` counts the round's items left,** not enemies (`round_items_remaining`).
  When it reaches 0 the round ends.
- **Ch1: the HUD is a timed split.** The render thread writes scroll 0 during vblank (`$C1A7`) and
  the camera scroll mid-frame (`$C092`). The store lands on scanline 34, so the camera takes over
  at line 35. No sprite-0 hit is involved.
- **Ch3: the attribute work area shares the stack page** (`$0170-$01FF`, above the game thread's
  stack, whose slot is `$3F`). A headless call with the stack at `$FD` gets overwritten by
  `build_stage_screen_layout`.

## New findings this pass

- **Sound.**
  - The note table is a chromatic octave, A1-G#2, within 3 cents.
  - The round music loops every 768 frames.
  - HURRY holds its trigger for 125 frames and the door wave for 123.
  - The bonus music is a single trigger covering the 210-frame intro card plus the 2,220-frame limit.
  - WAVs are rendered through `emu_harness.machines.nes.apu`; they are Namco's music and stay out of git.
- **Pictures.**
  - A trampoline's colour is its bounces left: green 3, blue 2, white 1.
  - Wave doors blink every 4 frames. `update_doors` redraws one door per frame, and only door-table slots 0-3 can blink.
  - Balloons are worth 200, the goal 2,000, PERFECT 5,000.
- **The bonus intro runs inside the layout builder.** For a bonus stage,
  `build_stage_screen_layout` turns rendering on, waits 210 frames on the thread switch, then
  clears the screen and draws the round.
- **The listing carries its assets** (`listing_art.json`, 54 entries):
  - ASCII art of every picture and pose;
  - decoded text;
  - layout comments above each ROM table;
  - a RAM-structure header generated from `vars.toml`.

## What the game exposed in the library

Each of these became a library fix with a test. The library is the durable output of this work.
- **Discovery:** a shared `JMP (ind)` stub is now resolved at each JSR caller (that was the `$EA39` door table).
- **Rendering:** sprite priority now follows the hardware rule: the first opaque sprite in OAM order wins, and a sprite set behind the background still hides the sprites under it. `frame()` also takes mid-frame scroll splits.
- **Audio:** the APU synthesizer.
- **Workflows:** the label, data and variable walks are now generic workflows inside the harness.

## Still open

- The synthesizer's audio hasn't been compared with a Mesen audio recording. The APU *writes* are
  verified; the *rendering* of them is checked only against the nesdev formulas and Chris's ear.
- `mansion_block_08` (`$D350`) is still unselected by any round. It may be spare data or a title layout.
- A field-by-field worked example of one mansion stamp block.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
