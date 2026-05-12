---
status: active
created: 2026-04-26
---
# Mappy — Object Records & State Machine
> 9 objects per bank, 16 bytes each, 23 states dispatched via indirect jump table. The structural shift from Adventure's 5-byte / 5-state dragons. *Sub-pixel positioning lives here.*

**Links:** [Mappy README](./README.md), [Mappy Reset & Frame Structure](./01-reset-and-frame-structure.md), [Adventure Memory Map (comparison)](../adventure/01-memory-map.md), [Adventure Dragon State Machine (comparison)](../adventure/06-dragon-state-machine.md), source: [`raw/mappy_bank_FF.asm`](../../../raw/mappy_bank_FF.asm), [`raw/mappy_bank_val.inc`](../../../raw/mappy_bank_val.inc)

## A 6502 footnote first

Adventure's `ORG $F000` and Mappy's `ORG $C000`-mirrored-to-`$FFFF` both end at the same 6 vector bytes. That's not a platform convention — **it's the 6502 itself**. The chip reads NMI/Reset/IRQ vectors from `$FFFA`–`$FFFF` regardless of where the code lives. Both consoles have ROM at the top of memory because the CPU demands it. The 2600 happens to put RAM and TIA at the bottom; the NES happens to put RAM and PPU registers at the bottom. Same skyline, different ground floor.

## The 16-byte object record

From `bank_val.inc`, every object is 16 bytes. The fields:

| Offset | Field | Notes |
|---|---|---|
| `$00` | `pos_X_fr` | X position **fractional** byte |
| `$01` | `pos_X_lo` | X position integer byte |
| `$02` | `pos_Y_fr` | Y position **fractional** byte |
| `$03` | `pos_Y_lo` | Y position integer byte |
| `$04` | `animation` | Current animation frame index |
| `$05` | `type` | 00=player, 01=coin-with-cat-face, 02=small (pink) cat, 03=fat (red) cat, ... |
| `$06` | `direction` | Facing / movement direction |
| `$07` | `timer` | General-purpose countdown |
| `$08` | (player only) | unnamed |
| `$09` | (player only) | unnamed |
| `$0A` | `jump_pos` | (player only) jump arc position |
| `$0B` | (player only) | unnamed |
| `$0C` | (player only) | unnamed |
| `$0D` | `movement` | (player only) movement state |
| `$0E` | (player only) | unnamed (`con_obj_AB` in source) |
| `$0F` | `state` | Current state-machine value |

**Three things to notice immediately:**

1. **Sub-pixel positioning.** Adventure's man moved 3 pixels per frame because integer math was the only option (chapter 1 of Adventure: `INC VBLANK,X` adds 1 pixel exactly). Mappy gives every object a 16-bit position via the fractional + integer bytes. **Movement is now `position += velocity` where velocity has its own fractional component.** Smooth diagonals, smooth deceleration, ramp-up/ramp-down — all impossible with integer-only positions.

2. **Animation as a slot.** Adventure had no animation field; sprite changes happened only via state-machine transitions (chapter 6 of Adventure: dragon state $02 = "eating ball" graphic). Mappy gives every object a dedicated animation byte that the renderer reads to pick the current frame. **Animation is now decoupled from gameplay state** — the same state can run multiple animation frames.

3. **Player has 7 extra fields ($08–$0E).** Only `obj_1[0]` is the player; everything else (cats, items, coins) uses the 9 shared fields and ignores the rest. The extras encode jump physics (`jump_pos`), movement state (`movement`), and other player-only mechanics. Adventure's man had no such extension — every object used the same 5-byte record because there were only ~5 axes of behavior. Mappy's player has more degrees of freedom than the cats.

## The 9-object bank — iteration loop

`sub_D8D8` (line 4707) walks the object table:

```asm
sub_D8D8:
       LDA #< ram_obj_1_data       ; $00
       STA ram_001E_t04_object_data
       LDA #> ram_obj_1_data       ; $04 — pointer is $0400
       STA ram_001E_t04_object_data + $01
bra_D8E0_loop:
       JSR sub_D939                            ; per-object setup
       JSR sub_DA2C_object_state_handler       ; ← state dispatch
       JSR sub_C305_update_sprites_for_animation   ; render to OAM shadow
       LDA ram_001E_t04_object_data
       CLC
       ADC #$10                                ; advance pointer 16 bytes
       STA ram_001E_t04_object_data
       CMP #$90                                ; reached $0490?
       BNE bra_D8E0_loop                       ; no → next object
```

Nine objects at `$0400`, `$0410`, `$0420`, ..., `$0480`. The pointer is held in zero-page `$1E/$1F` (`ram_001E_t04_object_data`) for indirect-Y access into each record. Loop exits when low byte hits `$90` (= `$0490` — past the 9th object).

**Compare Adventure's `CacheObjects` (chapter 3):**
- Adventure walked an 18-object table looking for in-room matches, picked 2 to display, rotated the cursor to share visibility across frames.
- Mappy walks 9 objects and processes **all 9 every frame** — state advance + render. No rotation needed because the NES PPU has 64 OAM slots (8 per scanline) versus the TIA's 2 player sprites.

The capability shift: where Adventure had to carefully ration which objects displayed per frame, Mappy can update every object's state and render every object's sprite without juggling. The "all 9 every frame" simplicity is what NES-era CPU cycles enable.

There's also a second object bank at `$04A0` (`ram_obj_2_data`) and a zero-page-resident `$00A0` (`ram_obj_3_data`) — likely effects, score popups, and transient objects. The exact partitioning is a chapter 3+ concern.

## The state machine — table-driven dispatch

Adventure's dragon state handling (chapter 6) was inline branches: `CMP #$00 / BNE / CMP #$01 / BEQ / CMP #$02 / BNE / ...`. Five states, ~30 lines of dispatch.

Mappy uses a **word-table indirect jump**:

```asm
sub_DA2C_object_state_handler:
       LDY #con_obj_state                  ; offset $0F
       LDA (ram_001E_t04_object_data),Y    ; read state byte
       TAX                                 ; X = state value
       LDA ram_p1_bonus_round
       BNE bra_DA1F_bonus_round            ; bonus round uses different table
       
       LDA tbl_DA42_normal_round,X         ; handler low byte
       STA ram_001C_temp
       LDA tbl_DA42_normal_round + $01,X   ; handler high byte
       STA ram_001D_temp
       JMP (ram_001C_temp)                 ; ← indirect jump to state handler
```

And the table:

```asm
tbl_DA42_normal_round:
       .word ofs_001_C14F_00_RTS    ; state $00 — no-op
       .word ofs_001_DA70_02        ; state $02 — standing/moving on platform
       .word ofs_001_DAC7_04        ; state $04 — jump off platform/hit wall
       .word ofs_001_DB94_06        ; state $06 — falling down
       .word ofs_001_DB45_08        ; state $08 — enemy cat touched player
       .word ofs_001_DC02_0A        ; state $0A — jumping off spring
       .word ofs_001_DC5C_0C        ; state $0C — flying up after spring
       .word ofs_001_DCFE_0E        ; state $0E — moving sideways after spring
       .word ofs_001_DD62_10        ; state $10
       .word ofs_001_DDA8_12        ; state $12
       .word ofs_001_DDC6_14        ; state $14
       .word ofs_001_C14F_16_RTS    ; state $16 — caught up in sound wave (no-op)
       .word ofs_001_C14F_18_RTS    ; state $18 — flying score points (no-op)
       .word ofs_001_DDD4_1A        ; state $1A — waiting for respawn
       .word ofs_001_DDE0_1C        ; state $1C
       .word ofs_001_DE2D_1E        ; state $1E
       .word ofs_001_DE61_20        ; state $20
       .word ofs_001_DB37_22        ; state $22
       .word ofs_001_DE25_24        ; state $24
       .word ofs_001_DE7A_26        ; state $26
       .word ofs_001_DE98_28        ; state $28
       .word ofs_001_DB55_2A        ; state $2A — right before $2C
       .word ofs_001_DB7B_2C        ; state $2C — player death animation
```

**23 normal states.** Plus a separate dispatch table for bonus rounds (`tbl_DA1F_bonus`). That's ~46 distinct behaviors a single object can be in across the two game modes.

### The state-as-table-offset trick

States are valued `$00, $02, $04, $06, ..., $2C` — **always even**. Each table entry is 2 bytes (a word pointer). So **the state byte is its own table offset** — no shift, no multiplication, just `LDA tbl,X`.

This is the same family of trick as:
- Adventure's TIA-names-as-offsets (chapter 4 of Adventure): `VBLANK = $01` is both a TIA register and a struct field offset because the values happen to align.
- Adventure's `RoomNumToAddress` (chapter 7): room number × 9 via `ROL ROL ROL + ADC original`, because room records are 9 bytes.

Mappy's variant: **state values are pre-shifted into table indices.** Adventure compressed multiple meanings into one constant; Mappy compressed the multiplication step into the data layout. Both move computation into data structure design.

### Multiple states sharing the same handler

States `$00`, `$16`, `$18` all point at `ofs_001_C14F_*_RTS` — three different state slots that mean "do nothing this frame." That's structural information about the gameplay:

- **$00 = "no state"** (object exists but is paused) — used during spawn freeze, perhaps
- **$16 = "caught in sound wave"** — Mappy's iconic door attack sweeps cats away; while caught, the cat just floats with the wave; per-frame logic isn't needed because animation handles the visual
- **$18 = "score points flying away"** — when a cat is defeated, score numbers fly off; same story (animation does the work)

**Three states, one no-op handler.** The state distinction matters for transitions (something else moves caught cats from $16 to $18 to $1A) but per-frame work is unnecessary. Adventure had something similar — state $01 (Dead) for dragons just returned immediately. Same idea, more granular.

### Bonus-round dispatch swap

The line `LDA ram_p1_bonus_round / BNE bra_DA1F_bonus_round` swaps the entire dispatch table during bonus rounds. **Same object slot, different state space, different behaviors.**

This is how Mappy implements the bonus-round "balloon catching" mode — same object infrastructure (same 16-byte records, same iteration loop, same OAM rendering) but a different jump table makes objects behave entirely differently. **One engine, two game modes, swapped via one byte of state.**

Adventure had nothing analogous. Adventure was one game mode. Mappy ships two playable modes from one set of object code.

## State semantics from the constants file

The `bank_val.inc` annotates many states with gameplay meaning. The annotated states tell us what mechanics the engine supports:

```
$00 — no state (paused)
$02 — standing/moving on platform (the default active state)
$04 — jump off platform / hit wall after $0E
$06 — falling down after $0C
$08 — enemy cat touched player
$0A — jumping off spring
$0C — flying up after $0A
$0E — moving sideways after $0A
$16 — caught up in sound wave
$18 — flying score points after $16
$1A — waiting for respawn after $18
$2A — right before $2C
$2C — player death animation
```

Plus 10+ states still labeled with `?` — even the disassembler hadn't fully decoded them. **Twenty-three states for what is, essentially, "an entity that can stand, jump, fall, get hit, and die."** That's a *lot* of decomposition compared to Adventure's dragon (idle / chase / attack-roar / dead / eaten-you = 5 states).

What did Mappy spend the new states on?

- **Multi-phase motion sequences.** "Jumping off spring" → "flying up" → "moving sideways" → "falling" is one trampoline arc, decomposed into 4 phases. Each phase has its own per-frame physics and its own transition rules. Adventure had no analog — characters moved in straight lines.
- **Damage / defeat sequences.** "Caught in sound wave" → "flying score points" → "waiting for respawn" → back to "standing." Three intermediate states for what could be a single "dead" boolean. The states encode the **animation timing** of being defeated.
- **Per-frame physics.** Each state can have its own gravity, friction, input response. Adventure's dragons had one motion model (pathfind toward target). Mappy's player has multiple — walking, jumping, falling, bouncing — each as a state with its own logic.

This is the storytelling-vs-logic axis applied at the state-machine level. **Adventure encoded behavioral diversity into design (different rooms, different dragons); Mappy encodes it into states (same player, multi-phase motion).** The capability cost is a 5× state-count, the gain is per-frame behavioral nuance.

## The shadow OAM render step — `sub_C305`

After state dispatch, every object calls `sub_C305_update_sprites_for_animation`. This reads the object's current animation byte, looks up its sprite tile pattern, and writes 4 bytes (Y, tile, attributes, X) to the **shadow OAM at `$0700`**.

The shadow OAM holds 64 sprites × 4 bytes = 256 bytes. It's an in-memory mirror of the PPU's internal OAM. Every frame, the main loop's first action after the NMI signal fires is `STA $4014` with `$07` — OAMDMA from `$0700`–`$07FF` to PPU OAM. The PPU then displays whatever was in the shadow OAM at that moment.

So the render pipeline is:
1. **Per-frame**: state handlers update `pos_X`, `pos_Y`, `animation`, etc.
2. **`sub_C305`**: reads object data, writes 4 bytes per visible sprite to shadow OAM.
3. **Next NMI**: main loop triggers OAMDMA, copying shadow OAM to PPU.
4. **PPU**: renders sprites from its OAM autonomously for the next frame.

**Three frames of latency** between state change and what you see on screen — but it's invisible at 60 fps. And the *programming model* is clean: write to RAM, the OAMDMA does the rest.

Adventure had no shadow OAM. Adventure wrote sprite bytes directly into TIA's GRP0/GRP1 registers in the kernel, on the exact scan line they should appear on (chapter 2 of Adventure). Mappy writes sprite bytes into RAM, and the chip handles when to actually display them. **The CPU-as-renderer became CPU-as-data-prep.**

## Efficiency catalogue (chapter 2 entries)

- **State value as pre-multiplied table offset.** States increment by 2 to match the word-table stride. `LDA tbl,X` directly indexes; no multiplication step.
- **Multiple states share one handler.** Three "no-op" states all point at the same `RTS` — different transitions, same per-frame work.
- **Bonus-round dispatch table swap.** One conditional branch in `sub_DA2C` swaps the entire state-machine semantics for bonus mode. Same record format, same iteration loop, swapped behavior.
- **Player-only fields are positional.** Bytes `$08`–`$0E` of every object record are reserved for player extensions; for non-player objects they're just unused. No per-type allocation; the schema is fixed and the player happens to use more of it.
- **Sub-pixel positions via fractional bytes.** Each axis has 16 bits of position data (8.8 fixed point). Smooth motion at zero extra code complexity.
- **Animation slot decouples sprite from state.** State machine controls *behavior*; animation byte controls *visual*. Same state can cycle through frames; same animation can apply across states.
- **One iteration loop for all 9 objects.** No type dispatch — every object goes through the same state handler, same render call. Per-type behavior comes from the state machine, not from the iteration code.
- **Shadow OAM at fixed page `$0700`.** OAMDMA only takes the high byte; placing the buffer at a page boundary makes the DMA call one instruction.

## What this confirms about the series

- **Adventure's chapter 6 dragon state machine** was a 5-state inline-branch dispatch. Mappy's 23-state table-driven dispatch is the same idea scaled — and the table-vs-branches choice scales differently. Adventure could afford branches; Mappy with 23 states needs the table to keep code size sane.
- **Adventure's "matrix slot order encodes role"** (chapter 6) was a way to compress *behavioral information* into data. Mappy's "state value IS table offset" is the same family — encode computation into data layout. Both move work from code into structure.
- **The shadow OAM pattern** retroactively explains Adventure's lack of a buffer — the TIA had no OAM, no sprite list, no abstraction layer. The CPU was the OAM. Mappy gets a hardware list to fill, and the existence of that list is what makes the "render is data prep" model possible.

## LLM-interpretation log

**Pure structure was sufficient for:**
- The object-iteration loop pattern (`STA pointer / loop body / ADC #$10 / CMP #termination / BNE loop`).
- The indirect-jump-via-table pattern (`LDA tbl,X / STA $1C / LDA tbl+1,X / STA $1D / JMP ($001C)`) — universal 6502 state-machine idiom.
- That state values are *deliberately* even-spaced because they index a word table — visible from the table layout itself.
- The shadow-OAM pattern (`STA $4014` from `$07` page) — recognizable from chip docs.

**Disassembler's labels and cross-refs were decisive for:**
- The `con_obj_*` constants (`pos_X_fr`, `pos_Y_lo`, `animation`, `type`, `direction`, `timer`, `jump_pos`, `movement`, `state`) — naming each field of the 16-byte record. **Without these, the record would be opaque indexed accesses.**
- The named state constants with gameplay descriptions ("standing/moving on platform," "jumping off spring," "caught in sound wave"). The state values themselves convey nothing; the comments reveal what mechanic each represents.
- The object-type constants (00 = player, 01 = coin, 02 = small cat, 03 = fat cat) — distinguishing slots without these would require running the game.
- The bonus-round flag's name (`ram_p1_bonus_round`) — the conditional `LDA $7C / BNE bra_DA1F_bonus_round` would be cryptic without it.

**Where I trusted vs verified vs disagreed with the disassembler:**
- **Trusted**: state name labels, object-type assignments. (No way to verify game-flavor naming from source alone; would need to play the game to confirm "small cat is pink, fat cat is red".)
- **Verified**: state-table layout (counted entries = 23, confirmed each is a `.word`), state-spacing = 2 (confirmed by comparing successive table addresses in source), iteration stride = 16 bytes (`ADC #$10`).
- **Suspicious / TBD**: the player-only fields `$08`, `$09`, `$0B`, `$0C`, `$0E` are unnamed — the disassembler hasn't decoded them. These will be findings to chase in chapter 4 (trampoline physics), where the jump_pos / movement / "AB" interactions live.

**Chip docs were load-bearing for:**
- That OAMDMA writes 256 bytes from a CPU page — explaining why shadow OAM is page-aligned at `$0700`.
- That OAM holds 64 sprites × 4 bytes — informing the meaning of "4 bytes per sprite" in the render step.
- The 8-sprites-per-scanline limit (relevant for chapter 3+ when we look at why some Mappy entities are rendered as background tiles, not sprites).

**Cumulative chapter knowledge from Adventure:**
- **The 5-state dragon vs 23-state Mappy contrast** is only meaningful with Adventure's chapter 6 in hand. The capability shift quantifies: 5× the states, 3× the bytes per object, sub-pixel positions vs integer-only.
- **The "state value as table offset" trick** reads as a Mappy-era variant of TIA-names-as-offsets — encoding computation into data layout. Adventure compressed addresses; Mappy compressed multiplications.
- **The "shadow OAM as data prep" model** sharply distinguishes from Adventure's "CPU is the renderer" model. Without the chapter-2-of-Adventure context, Mappy's `STA $4014` looks like one boring instruction; with it, it's the entire structural difference.

**Big find of chapter 2:** the **bonus-round dispatch swap** — `LDA ram_p1_bonus_round / BNE / different table`. One engine, two game modes, swapped via one byte. This is Mappy's version of Adventure's "three game variants in 24 bytes" finding (chapter 7 of Adventure) — **mode-as-data, swapped at runtime, one infrastructure serving multiple gameplay flavors.** The pattern repeats; the implementation evolves.

## What chapter 2 sets up for chapter 3

- **The shadow OAM** is the bridge to PPU pipeline mechanics. Chapter 3 will trace how OAMDMA, VRAM updates, and the scroll setup integrate during VBlank.
- **"Background as sprites"** — the doors, bells, pickups that look like sprites but are actually nametable tile patches. Mappy avoids the 8-per-scanline sprite limit by promoting visually-static objects to the background layer. This deserves its own chapter.
- **The unnamed player fields ($08–$0E)** are the hooks for chapter 4 (trampolines & physics). The jump arc and movement state live there; we'll trace what each byte does.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
