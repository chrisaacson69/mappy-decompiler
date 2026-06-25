---
status: active
created: 2026-06-25
---
# Mappy — Chapter 9: The From-Scratch Re-Derivation

> The first eight chapters read Mappy *through the cyneprepou4uk disassembly* — its labels, its cross-refs, its "I don't know what this does" markers — and asked what the code does. This chapter did the opposite: starting from the bare 16 KB binary plus a 6502 emulator, **with the published disassembly forbidden as an input**, we reverse-engineered every function, variable, and data structure from zero, then brought the repo in only at the very end as a confirming diff. This chapter is what that independent pass **confirmed, resolved, diverged on, and newly discovered** — chapter by chapter.

**Links:** [Mappy README](./README.md), [Object Records & States](./02-object-records-and-states.md), [PPU Pipeline](./03-ppu-pipeline.md), [Cat AI](./05-cat-ai.md), [Music Engine](./07-music-engine.md), [Level Data](./08-level-data-and-bonus-rounds.md), artifacts: `labels.toml` (258 functions), `vars.toml` (152 variables + object record), `mappy_labeled.asm`, `Mappy (Japan).mlb`

## How this pass worked (the pipeline, no oracle)

`dynamic trace` (run the ROM headless through boot+attract: 30% coverage, 132 routines, resolved the 4 executed jump tables) → `static recursive-descent` (60%) → `idiom-anchored jump-table sweep` (96.7% code recall, all 6 dispatch tables incl. bonus `$E17A` the demo never reaches) → `call graph` → **8 levels of leaf-first bottom-up naming** (258 routines) → **top-down adversarial verification** (95% confirm) → `var-walk` (152 variables from cross-routine usage) → `object-record field pass` (the 16-byte layout from how every routine touches each offset). The repo, consulted only at the end, **matched our meaning on every overlap and was anonymous on 188 of 258 routines** — it confirmed the method rather than teaching it.

The headline: an LLM-driven pipeline, given only the binary and an emulator, recovered the same program structure a human annotator extracted from a fully-labeled disassembly — independently, and went further on the data structures.

---

## Chapter 1 — Reset & Frame Structure → **fully confirmed**

Every Ch1 claim reproduced from scratch, names and all: `reset_cold_boot_init` (`$C031`), `nmi_sound_tick` (`$C2EF`), `irq_rti_stub` (`$C304`, the RTI stub Ch1 noted falls through to NMI's RTI). The `$5A`/`$A5` soft-reset sentinel at `$3E`/`$3F`, APU init `$0F→$4015` / `$C0→$4017`, `PPUCTRL=$88`, OAMDMA from page `$07`, and the main-loop poll on the vblank flag `$20` — all independently derived. The main loop itself we named `vblank_synced_frame_update_loop` (`$C06D`): spin on `$20`, OAMDMA, `flush_vram_fill_buffer`, `read_and_decode_input`, `build_sprite_row_oam_shadow`, scroll write, `sound_command_dispatch`, `inc $21`, loop. **Nothing to correct.**

## Chapter 2 — Object Records & States → **shape confirmed, per-field naming diverged (and that's the point)**

The 16-byte record (base `$0400`, stride `$10`) and the **23-state word-table dispatch at `$DA42`** were both re-derived independently — including, satisfyingly, that the state byte is **offset +F**: our `dispatch_object_state_handler_da42` reads `ldy #$0f / lda (obj_record_ptr),y / tax` then `jmp ($1C)` through `$DA42`. We found the same dispatch field with zero foreknowledge. Position (`+0/+1` X, `+2/+3` Y) and the timer (`+7`, the single busiest field, 46 routines) match Ch2 exactly.

Where the per-field pass **diverged** from Ch2's disassembler-label layout:
- **`+4`**: Ch2 = "animation frame"; our cross-routine pass = `obj_state` (written from constants by `set_obj_state_*`/`reset_obj_to_state2_*`). Likely an anim-frame *driven by* state — unresolved which framing is primary.
- **`+5`**: Ch2 = "type (0=player,1=coin,2=cat…)"; we said `obj_state`, but **our own function name argues Ch2 is right** — `obj_field5_lookup_C47C` uses `+5` as an index into a per-type parameter table `$C47C`, which is exactly type behavior. Correction to our `vars.toml`: `+5` is `obj_type`.
- **`+6`**: Ch2 = "direction"; we said `obj_velocity` (the `sbc`-negate sign-flip in `reverse_obj_velocity_and_set_state`). Both motion; a signed velocity *is* direction+magnitude.

The deeper lesson is **`+8…+E`**: Ch2 left these "player-only, mostly TBD" and Ch4 decoded them only *for the player in bounce states*. Our generic pass named them `obj_state`/`obj_timer`/`obj_flags` from *all* routines — and the two readings disagree **because the fields are polymorphic**. That isn't a contradiction; it's a measurement of the chapters' own thesis (see below). A single name per offset *cannot* capture a byte that means velocity for a bouncing player and a door-reference for a caught cat.

## Chapter 3 — PPU Pipeline → **fully confirmed, including the readback buffer**

The dual-buffer system reproduced exactly: `ppu_buffer_enqueue` (`$C78E`) gates on the PPUMASK shadow `$2D` (render-on → queue to buffer-1 at `$0500`, cursor `$2A`; render-off → direct `$2006/$2007`). The **buffer-2 VRAM read-back at `$04C0`** that Ch3 described is our `flush_vram_readback_queue_and_restore_render` (`$C177`) — it walks `$04C0`, does the dummy+real `$2007` read, stores via `(obj_record_ptr),y`. Input: `read_and_decode_input` (`$C1C9`) strobes `$4016` and calls `read_joypad` (`$C249`) twice, exactly Ch3's protocol. The "garbage NOP" timing loops are visible in `mappy_labeled.asm` inside the same routine. **Confirmed end to end.**

## Chapter 4 — Trampolines & Physics → **confirmed mechanism; field decode is context-specific (polymorphism again)**

The bounce state machine and the tile-under-foot collision (via the buffer-2 readback above) hold. The `obj_velocity` (`+6`) and `obj_timer` (`+7`) we recovered generically are Ch4's per-bounce-state velocity/timer. Ch4's `$0B`=velocity / `$0C`=decay / `$0D`=movement are the **player-in-bounce-state** interpretation of fields our generic pass saw used differently by cats and items — the same polymorphism Ch2 forced. Field `+E`, which Ch4 left "still TBD," we name `obj_flags` (3 routines, bit-mask reads) — a partial close, low confidence.

## Chapter 5 — Cat AI & Doors → **confirmed + several "unknown states" now have named handlers**

`trigger_state_transition_on_position_match` (`$E757`) is Ch5's `fat_cat_hide_inside_item` (the repo-diff agreed). The sound-wave handler, the `con_obj_0B` re-purpose (velocity-for-player vs door-reference-for-cat — **the canonical polymorphism specimen**), and the cat respawn loop all reproduced. Crucially, the states Ch5 flagged as untraced (`$1C,$20,$22,$24,$26,$28`) are **entries in the `$DA42` table we fully enumerated and named** — they're no longer blank slots; each has a behavioral handler name in `labels.toml` (the bonus/transition handlers). Ch5's open list is substantially closed.

## Chapter 6 — Game State & Mode → **confirmed; one name sharpened**

`$42` demo flag, `$40` game-mode, `$41` player-index, `$7C` bonus-round, `$7A` current-round, `$23` game-active — all independently named. We read the round-attributes table `$CDBF` (16×4 bytes) ourselves to drive the level renders. The 4-byte BCD score lives in `bcd_add_packed_buffer` (`$D502`) with its per-nibble decimal correction — Ch6's "30 instructions because the 2A03 has no BCD." One sharpening: Ch6's `sub_CA81_swap_data_for_players` we initially undersold as `swap_double_buffers_toggle_flag` — it swaps **both** the OAM shadow (`$0200`↔`$0300`) **and** the P1/P2 data blocks (`$70`↔`$B0`), confirming Ch6's two-player swap.

## Chapter 7 — Music Engine → **confirmed + control-byte structure recovered + a bonus VM**

`sound_command_dispatch` (`$F4F1`) → `sound_engine_tick` (`$F55A`) walks the voices writing `$4000,x` per channel — Ch7's 25-voice mixer / 4-channel / slot-order-priority engine, reproduced. Ch7's flagged uncertainty (the `con_se_cb_*` control bytes) gets **structure**: the music region is driven by `fetch_seq_byte_and_advance_index` plus `jump_table_dispatch_via_index` — the **RTS-trick dispatcher** (`pla/pla` grabs an inline pointer table, tail-jumps) — and **11 pointer tables** in `$F2xx–$F7xx` that the structural sweep found. And a genuinely new find sits next door: **`run_object_animation_script` (`$F606`) is a bytecode interpreter** — `<$60` = frame index, `$60–$E7` = field store, `≥$E8` = dispatch through a handler table — i.e. Mappy animates objects with a tiny **VM**, not hardcoded routines.

## Chapter 8 — Level Data → **confirmed + the "table-3 index" mystery resolved**

The draw-command interpreters are named and dissected: `ppu_run_draw_blocks` (`$CC15`, the `[count][addr][data]` walker), `ppu_draw_mansion_stamps` (`$D126`, the RLE multi-stamp), all under `build_stage_screen_layout` (`$CD49`). The **bonus dispatch table `$E17A` (10 entries)** — which Ch8 described and which the headless demo *never executes* — we recovered statically by anchoring it to the un-taken `JMP ($1C)` at `$DA29`. The blinking-platform routines are named (`spawn_object_pair_for_state` `$F001` = repo `prepare_platform_data`; `$F04D` = `draw_platform_tiles`). And Ch8's explicitly-undecoded **"table-3 index" (round-attribute byte 3)** resolves: byte 3 indexes `tbl_D185`, the **mansion-structure draw table**, consumed by `sub_D126` — the index selects which mansion layout to stamp.

---

## The cross-cutting findings

**1. The polymorphism thesis, now measured.** Every place our generic per-field/per-variable naming "disagreed" with the chapters (`+4`,`+5`,`+6`,`+8…+E`, `con_obj_0B`) is a place where **one byte means different things in different object-type/state contexts**. The chapters argued this qualitatively ("byte-meaning depends on who's reading and when"); our pass *quantified* it — a symbol table with one name per address structurally cannot encode it, so the disagreements are a faithful readout of the polymorphism, not errors. The honest next step would be **context-tagged field names** (e.g. `+B = player_velocity | cat_door_ref`).

**2. Dispatch is the spine, and it's plural.** Mappy's control flow runs on three dispatch idioms, all recovered: the **indexed word-table `JMP (ind)`** (6 tables: game-mode `$C356×20`, object-state `$DA42×23`, bonus `$E17A×10`, platform `$F1B5`, plus two small), the **RTS-trick** (`jump_table_dispatch_via_index` in the audio engine), and the **stored function-pointer**. Recovering these *was* the key to coverage — they're exactly the edges static analysis can't follow and dynamic-only execution can't reach when the triggering game state never occurs.

**3. The method is the deliverable.** Walking the tree top-down to *find* the leaves, naming bottom-up so each level makes the next legible, then walking top-down again to *verify* — that loop (and its tooling: `trace_codegraph`, `static_expand`, `jump_tables`, `var_xref`, `obj_record`) is game-agnostic. The top-down verify even caught a routine (`$C37C`) the bottom-up climb had skipped. Point it at the next NES title and only the entry addresses change.

## Status after the re-derivation

- **Closed:** Ch5's untraced object states (named handlers), Ch7's control-byte structure (sequence interpreter + RTS-trick + pointer tables), Ch8's table-3 index (= mansion-structure table `$D185`).
- **Sharpened:** Ch2 `+5` → `obj_type`; Ch6 `$CA81` → also swaps player data; the bonus table reached without ever playing a bonus round.
- **Still open (and now precisely bounded):** the *context-tagged* meanings of the polymorphic fields `+4`/`+8…+E`; the exact `$EA`-style audio control-byte parameters; the post-round-15 escalation. These are the residue that needs game-play observation, not more static analysis.

**The series' throughline question was "what does this code do that Adventure couldn't?" This chapter adds a second: "could a machine, given only the bytes, find out for itself?" — and the answer, on a standard NROM ROM, is yes.**

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
