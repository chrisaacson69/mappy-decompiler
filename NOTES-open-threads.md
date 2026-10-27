---
status: active
created: 2026-06-26
---
# Mappy — open threads / follow-ups

> Parking lot for loose ends found while tracing attract mode and level data.
> Each entry has enough grounding (addresses + what's known) to resume cold.
> When one is closed, fold the finding into the relevant chapter + the toml symbol tables.

**Links:** [README](./README.md), [Game State (ch6)](./06-game-state.md), [Level Data (ch8)](./08-level-data-and-bonus-rounds.md)

## Level-creation data (chapter 8 region)

- **Draw-block byte grammar.** We labeled the 18 draw-block blobs (`palhud_block_*`,
  `frameitem_block_*`, `mansion_block_*`) but not the byte format *inside* one.
  - `ppu_run_draw_blocks` ($CC15) / `ppu_draw_blocks_b` ($CF69): blocks are
    `[?][ppu_addr][tiles…][0-terminator]` — walk the walker to pin each field exactly
    (e.g. `palhud_block_00` $CC4B = `11 4B 20 A0 A1 A2 A3 A4 A5 A6 A7 00 …`).
  - `ppu_draw_mansion_stamps` ($D126): RLE form `[count][data_ptr][N × ppu_addr]` with a
    `(runlen, tiles, signed-delta)` inner run (per its label `why`). Annotate one mansion
    block field-by-field as the worked example.
- **`mansion_block_08` ($D350).** `mansion_idx 8` is never selected by any round in
  `tbl_round_attributes` ($CDBF). Confirm whether it's a title/intro layout, a spare, or
  dead data. (Check non-`$CD49` callers of `ppu_draw_mansion_stamps` with `Y=8`.)
- ~~**Trampolines & blinking platforms are a DIFFERENT path.**~~ **Resolved 2026-10-27** → [ch10](./10-build-tool-pass.md): the "blinking platforms" are floor traps (rounds 12-14, `spawn_floor_traps` $F001); trampolines load from `load_round_trampolines` ($E35B), items from `ptr_round_items` ($E798). Original note: They are *objects*, not
  nametable tiles, so they don't come from the `$CDBF`/`$CC41`/`$CFA6`/`$D185` tables.
  Source is the object-spawn side: `spawn_objects_from_level_descriptor` ($E5C5, level
  descriptor ptr at $E798/$E799) and `$F001` (`prepare_platform_data`; blinking platforms
  on rounds 11–13, computed `round*2 - $15 < 6`). Separate labeling pass — find/label the
  per-round object/trampoline descriptor tables.

## Attract / demo (chapter 6 region)

- **What trips the demo exit: RESOLVED 2026-10-02, the mouse is caught** (state `$08`,
  `$4B`=1, `$7B`=5 of 10; ch6). The earlier "stage-resolution" reading was wrong. ~~Still
  open: what `$7B` counts as it falls 10→5~~ **Resolved 2026-10-27** → [ch10](./10-build-tool-pass.md): `round_items_remaining`, the items left to take (it reaching 0 raises `$4F` at `$E686`), via
  `resolve_object_position_capture_and_score` ($E660).
- **`inc $040E` = the door/trap action?** Input side RESOLVED: real play copies `$22`
  ("A or B pressed" history) into `$040E`, so the pulse is a one-frame A/B press, and the
  script replays frame-exact through the pad (`demo_in_real_game.py`). ~~Still open: what
  reads `$040E` (player field $0E) and whether it drives the doors.~~ **Resolved 2026-10-27** → [ch10](./10-build-tool-pass.md): record field
  +E is `obj_buttons`, a shift register of A/B presses (vars.toml `[[obj_field]]`); it does drive
  the doors: `player_opens_nearest_door` ($E976) opens one only when `+E & 3 == 1` (pressed this
  frame, not the last).

- **Hidden state carried into a round = the frame-counter phase (measured 2026-10-02,
  `seed_test.py`).** Pressing Start at 7 different frames then playing identical in-round
  inputs: the player, the first cat records (`$0410`/`$0420`), items, score and lives match on
  every frame, but cat records `$0430`-`$045F` diverge from about 1,700 frames in. At "live"
  the only lasting difference is `$21` (named `cur_obj_state`). It tracks the Start delay one
  for one (`$78`, `$79`, `$7A` for starts 60/61/62; `$9D` for 97), so it is a free-running
  frame counter. No separate RNG found yet. ~~Open: which cat routine reads `$21`, and is the
  seed space really one byte (256 phases)?~~ **Resolved 2026-10-27** → [ch10](./10-build-tool-pass.md): `choose_cat_target_floor` takes bit 0 of
  the ROM byte at `$C000 + frame_counter` (the copyright text and the code after it), so the
  seed is the one-byte frame-counter phase.

## Symbol-table cleanups (from-scratch mislabels, pattern: pointer→counter)

- ~~**`$7B` rename.**~~ **Resolved 2026-10-27** → [ch10](./10-build-tool-pass.md): renamed `round_items_remaining` (items, not enemies). Original note: Currently `draw_data_ptr` (pointer) but it's the per-stage enemy
  counter (set `$E5D8`, dec'd in `$E660`, tested at `$E682`). Same mislabel pattern we
  fixed for `$70`/`$B0` (p1_lives/p2_lives) and `$3D` (demo_script_cursor). Rename to
  `stage_object_count` (or similar) in `vars.toml` + regen.
- ~~**General sweep.**~~ **Resolved 2026-10-27** → [ch10](./10-build-tool-pass.md): variables round 2 rebuilt var_xref on decoded instructions only (570 links were data read as code); no shared names remain. Original note: Worth a pass over the remaining `role = "pointer"` vars that are only
  ever touched by `inc`/`dec`/`#imm` (never `(zp),y`) — they're likely counters mis-inferred
  from X-indexed indirects, as `$70` was from `ora ($6f,x)` at the data byte `$D213`.

## Done this session (for context)
- Demo input = scripted track `tbl_demo_input_script` ($FFE1), played via `$D98A`; not AI.
- Lives = `p1_lives` ($70) / `p2_lives` ($B0). Two play loops (real `$CA28` lives-gated;
  demo `$FF65 @FFBC` flag-gated). `$D4CA` is the score gate, not the input gate.
- Level data labeled: `tbl_round_attributes` + 3 pointer tables + 18 blocks.
- `asm_gen.py` last-routine-body bug fixed (`$FF65`–`$FFFF` now emits).

## Future: AI play (Chris, 2026-10-27)

Two goals, two ways to drive the game:

- **Goals.**
  - A **speedrun**: past round 16 as fast as possible. Chris is checking the community's actual end point.
  - A **high-score run**:
    - Can every bonus be taken in every round?
    - When does chasing in-round bonuses (item pairs, door waves, the coin) cost more than the round's end bonus?
    - Since the rounds repeat, can the run go on for ever?
- **Implementations.**
  - A **TAS script**: an input log from power-on. Best for the speedrun, and RNG manipulation is in reach.
  - **Direct control**, deciding each frame from state. Best for the high score, since an infinite run can't be one finite script.

What exists and what the finished disassembly adds:
- **Search.** `mappy_search.py` (2026-10-02, before naming) runs emu-harness's segment and beam search through Mesen. It clears round 1 with no deaths (3,292 frames; 2,399 frames robust across four Start phases), replay-verified from power-on.
- **The repeat structure, from the code** (`advance_to_next_round` $D6E8):
  - The layout is `stage_number & $0F`, so the 16 rounds repeat.
  - The speed and difficulty row (`load_stage_params` $F3C1, 6 bytes by `stage_index`) climbs to `$1F`, then cycles `$1C-$1F` for ever.
  - So after the first 28 rounds the game is periodic: the same 16 layouts against the same 4 difficulty rows. An infinite run is a finite set of round configurations, played again and again.
- **The randomness is fully known.**
  - The cats' only random bit is ROM byte `$C000 + frame_counter` (`choose_cat_target_floor`).
  - The only hidden state carried into a round is the frame-counter phase (`seed_test.py`).
  - So RNG manipulation means choosing *when* things happen. Whether a looping script can work turns on the frame counter: does each lap of the cycle take a frame count that brings `$21` back to the same phase, with the same object state?
- **A forward model, proven.** `live_verify.py` shows the game's own per-object step, run headless on the library CPU, reproduces the real game step for step. A planner could look ahead with the game's own code rather than an approximation.
- **Open:** extra-life thresholds and the lives cap (they bound the score run's margin), and how the score counter wraps.
