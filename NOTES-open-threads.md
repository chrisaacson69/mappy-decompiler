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
- **Trampolines & blinking platforms are a DIFFERENT path.** They are *objects*, not
  nametable tiles, so they don't come from the `$CDBF`/`$CC41`/`$CFA6`/`$D185` tables.
  Source is the object-spawn side: `spawn_objects_from_level_descriptor` ($E5C5, level
  descriptor ptr at $E798/$E799) and `$F001` (`prepare_platform_data`; blinking platforms
  on rounds 11–13, computed `round*2 - $15 < 6`). Separate labeling pass — find/label the
  per-round object/trampoline descriptor tables.

## Attract / demo (chapter 6 region)

- **What trips the demo exit: RESOLVED 2026-10-02, the mouse is caught** (state `$08`,
  `$4B`=1, `$7B`=5 of 10; ch6). The earlier "stage-resolution" reading was wrong. Still
  open: what `$7B` counts as it falls 10→5 (it reaching 0 raises `$4F` at `$E686`), via
  `resolve_object_position_capture_and_score` ($E660).
- **`inc $040E` = the door/trap action?** Input side RESOLVED: real play copies `$22`
  ("A or B pressed" history) into `$040E`, so the pulse is a one-frame A/B press, and the
  script replays frame-exact through the pad (`demo_in_real_game.py`). Still open: what
  reads `$040E` (player field $0E) and whether it drives the doors.

## Symbol-table cleanups (from-scratch mislabels, pattern: pointer→counter)

- **`$7B` rename.** Currently `draw_data_ptr` (pointer) but it's the per-stage enemy
  counter (set `$E5D8`, dec'd in `$E660`, tested at `$E682`). Same mislabel pattern we
  fixed for `$70`/`$B0` (p1_lives/p2_lives) and `$3D` (demo_script_cursor). Rename to
  `stage_object_count` (or similar) in `vars.toml` + regen.
- **General sweep.** Worth a pass over the remaining `role = "pointer"` vars that are only
  ever touched by `inc`/`dec`/`#imm` (never `(zp),y`) — they're likely counters mis-inferred
  from X-indexed indirects, as `$70` was from `ora ($6f,x)` at the data byte `$D213`.

## Done this session (for context)
- Demo input = scripted track `tbl_demo_input_script` ($FFE1), played via `$D98A`; not AI.
- Lives = `p1_lives` ($70) / `p2_lives` ($B0). Two play loops (real `$CA28` lives-gated;
  demo `$FF65 @FFBC` flag-gated). `$D4CA` is the score gate, not the input gate.
- Level data labeled: `tbl_round_attributes` + 3 pointer tables + 18 blocks.
- `asm_gen.py` last-routine-body bug fixed (`$FF65`–`$FFFF` now emits).
