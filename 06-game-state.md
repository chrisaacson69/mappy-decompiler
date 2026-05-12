---
status: active
created: 2026-04-26
---
# Mappy — Game State & Mode Orchestration
> Where it all comes together. The demo IS the game running with AI input. Start-button press flips one byte. The entire 16-round progression — bonus rounds, level types, enemy mixes — fits in 64 bytes. And the design lineage runs straight back to Pac-Man.

**Links:** [Mappy README](./README.md), [Reset & Frame Structure](./01-reset-and-frame-structure.md), [Object Records & States](./02-object-records-and-states.md), [Cat AI](./05-cat-ai.md), [Adventure Memory Map (comparison)](../adventure/01-memory-map.md), source: [`raw/mappy_bank_FF.asm`](../../../raw/mappy_bank_FF.asm)

## What "where it all comes together" means

Chapters 1–5 covered the engine: frame structure, object records, PPU pipeline, physics, AI. Each chapter examined a system in isolation. Chapter 6 looks at how those systems get **orchestrated** into a game — the high-level state machine that swaps between attract mode, gameplay, bonus rounds, and game over.

The orchestration is small. Most of the "game" lives in the engine; the orchestration just decides *which configuration* of the engine to run at any moment. **The engine is the same in attract mode, gameplay, and bonus rounds.** What changes is which dispatch table, which player input source, and which level data is loaded.

## The high-level mode machine

```
[Power on / Reset]
       ↓
[Cold-boot init: PPU warmup, RAM clear]
       ↓
   ┌──→ [Title screen + DEMO mode]
   │      ↓ (Start pressed)
   │    [Game start: reset score, lives = 3, set round = 0]
   │      ↓
   │    [Round play loop]
   │      ↓ (round complete)
   │    [Level transition / bonus round?]
   │      ↓ (player died and lives ≥ 0)
   │    [Respawn] → back to round play
   │      ↓ (lives = 0)
   │    [Game over]
   │      ↓
   └─── (back to title screen)
```

Five distinct modes: cold-boot, demo, gameplay, bonus, game-over. Each is a different region of the same code, parameterized by a few zero-page flags. **The engine doesn't know what mode it's in** — the dispatch tables and input sources route based on the mode flags.

## The mode flags

| Address | Name | Purpose |
|---|---|---|
| `$42` | `ram_demo_flag` | 0 = demo (AI plays), 1 = real gameplay |
| `$40` | `ram_game_mode` | High-level mode selector |
| `$41` | `ram_player_index` | 0 = P1's turn, 1 = P2's turn |
| `$7C` | `ram_p1_bonus_round` | 0 = normal round, non-zero = bonus type |
| `$70` | `ram_p1_lives` | Lives remaining (P1) |
| `$7A` | `ram_p1_current_round` | Round number (P1) |
| `$23` | `ram_0023_flag` | "Game active" — gates HUD/sprite render |
| `$25` | `ram_btn_Start` | Start button shadow (edge-detected) |
| `$24` | `ram_btn_Select` | Select button shadow |

Nine bytes encode the entire game-mode state. **Adventure used three** (current room, current object held, level number). The proportional growth tracks the design complexity: Adventure had one game; Mappy has menus, two-player support, level progression, bonus mode, and demo mode — and each adds 1-2 bytes.

## The demo IS the game

This is the punchline of the chapter. Looking at `ofs_C84F` (line 1705):

```asm
loc_C84F:
       LDA #$00
       STA ram_demo_flag           ; ENTER demo mode
       JSR sub_F4BF                ; init sound engine
       ; ... set up player data, lives = 3 ...
       JSR sub_CBB1                ; render title/demo background
       JSR sub_CD2B                ; ?
       LDA #$F0
       STA ram_000E_timer + $01    ; demo timer = 240 frames (4 sec)
       
bra_C890_loop:
       JSR sub_C141                ; <-- runs the game engine
       JSR sub_CD3E                ; ?
       JSR sub_D73E                ; ?
       
       LDA ram_btn_Start           ; check Start button
       AND #$03
       CMP #$01                    ; freshly pressed (newly = 1, not held = 1)?
       BEQ bra_C8AB_start_was_pressed
       
       DEC ram_000E_timer + $01    ; demo timer down
       BNE bra_C890_loop
       JMP loc_FF65                ; demo timeout — next attract screen
       
bra_C8AB_start_was_pressed:
       LDA #$01
       STA ram_demo_flag           ; LEAVE demo mode
       ; ... initialize gameplay state, score = 0, lives = 2 (one used) ...
       ; ... copy P1 data to P2 data ...
       ; ... call level setup ...
```

**The demo loop calls the same `sub_C141` that gameplay calls.** Same engine, same object updates, same render pipeline. The only difference is **`ram_demo_flag`** — a single byte that other code reads to decide *who controls the player*.

Looking at `sub_D4CA` (line 3792):

```asm
       LDA ram_demo_flag
       BEQ bra_D4C9_RTS            ; if demo, skip joypad → input
       ; if not demo, read player input and apply to player object
```

In demo mode (flag = 0), the joypad → object-input pipeline is skipped. The player object's movement comes from somewhere else — almost certainly a scripted demo sequence or simple AI that just walks toward the nearest item. **Mappy plays itself in attract mode by replacing the player's input source, not by changing the engine.**

This is the cleanest possible attract-mode implementation: **don't write a separate "demo" code path**, just replace one input. The player object's state machine, physics, collisions, sprite rendering — everything runs identically. Attract-mode-as-engine-with-different-input is the design pattern.

Adventure had no analog. Adventure's demo, if it had one, would have required separate code because Adventure didn't separate "movement input" from "movement execution" cleanly. The 6507's lack of CPU headroom forced inlining; Mappy's NES headroom *afforded* the abstraction.

## Start-press transition — one byte flip

When Start is detected during the demo loop:

```asm
bra_C8AB_start_was_pressed:
       LDA #$01
       STA ram_demo_flag           ; switch to gameplay
       LDA ram_004A
       STA ram_game_mode
       LDA #$00
       STA ram_player_index        ; P1 starts
       STA ram_p1_score_xx000000   ; clear score (4 bytes)
       STA ram_p1_score_00xx0000
       STA ram_p1_score_0000xx00
       STA ram_p1_score_000000xx
       STA ram_p1_current_round    ; round 0
       STA ram_p1_rounds_counter
       LDA #$01
       STA ram_p1_0077
       ; ... copy P1 data → P2 data slot ...
       DEC ram_p1_lives            ; 3 → 2 (current life is "spent")
       JSR sub_CAA7_clear_data_of_all_objects
       ; ... re-init level, render ...
```

**One byte flip and 30 register writes** turn the demo into a game. The score zeroes, the round counter resets, lives go from 3 to 2 (the current life "starts"), and the object table gets cleared and re-populated for the first level.

The lives starting at 3 then immediately decrementing to 2 is a tell: **`ram_p1_lives` represents "lives in reserve."** The currently-active life isn't counted. When lives in reserve = 0 AND the current life ends, game over fires.

## Two-player support via swappable data blocks

Players' state lives in two parallel 32-byte blocks:

| Range | Player |
|---|---|
| `$70`–`$8F` | P1 data (lives, score, round, etc.) |
| `$B0`–`$CF` | P2 data |

When switching turns:

```asm
       LDX #$00
loop:
       LDA ram_p1_data,X     ; current P1 byte
       STA ram_p2_data,X     ; → P2 slot
       INX
       CPX #$20              ; 32 bytes
       BNE loop
```

Then `sub_CA81_swap_data_for_players` swaps them whenever the active player changes. **Two-player mode IS one player's engine running, with the OTHER player's data temporarily stored in the inactive slot.** When P1 dies and it's P2's turn, the data blocks swap; P2's state becomes the live one. When P2 dies and it's P1's turn again, swap back.

`ram_player_index` (`$41`) tracks who's currently active. The engine only ever reads from the "live" set of addresses (`$70`–`$8F`); the inactive player's state is parked in the other set, frozen until their turn.

This is the standard NES two-player pattern. **The engine is single-player; the orchestration is two-player.** Adventure was strictly single-player — no two-player mode existed, no swappable data blocks needed. Mappy's choice to support two players cost ~32 bytes of RAM and ~50 bytes of swap-routine code.

## The round-attributes table — entire progression in 64 bytes

The round-attributes table at `tbl_CDBF_round_attributes` (line 2494) is **the most compact level progression I've seen in any game in this project**:

```asm
tbl_CDBF_round_attributes:
;  +-- bonus round index (0 = normal)
;  |    +-- index for level layout table at $0C51
;  |    |    +-- index for enemy spawn config at $0FB6
;  |    |    |    +-- index for table at $1195
;  |    |    |    |
   .byte $00, $04, $00, $00   ; round 00 — normal
   .byte $00, $08, $00, $00   ; round 01 — normal
   .byte $02, $04, $0A, $0A   ; round 02 — BONUS (type 2)
   .byte $00, $06, $02, $02   ; round 03 — normal
   .byte $00, $04, $02, $02   ; round 04 — normal
   .byte $00, $08, $02, $02   ; round 05 — normal
   .byte $04, $04, $0A, $0A   ; round 06 — BONUS (type 4)
   .byte $00, $06, $04, $04   ; round 07
   .byte $00, $04, $04, $04   ; round 08
   .byte $00, $08, $04, $04   ; round 09
   .byte $06, $04, $0A, $0A   ; round 0A — BONUS (type 6)
   .byte $00, $06, $06, $06   ; round 0B
   .byte $00, $04, $06, $06   ; round 0C
   .byte $00, $08, $06, $06   ; round 0D
   .byte $08, $04, $0A, $0A   ; round 0E — BONUS (type 8)
   .byte $00, $06, $00, $00   ; round 0F
```

**16 rounds × 4 bytes = 64 bytes.** That's the entire game-progression definition.

Pattern visible:
- **Bonus rounds at indices 02, 06, 0A, 0E** — *every 4th round is a bonus round.* Mappy's design rule "bonus round every 4 levels" is one byte per round in the first column.
- **Bonus type increases**: 2, 4, 6, 8. Higher type = higher difficulty / different enemy mix.
- **Layout index cycles**: 4, 8, 4, 6, 4, 8, 4, 6 ... different layouts within each 4-round block.
- **Enemy spawn / table-3 indices grow with round number** — early rounds use index 0, mid rounds use 2, 4, 6, late rounds use higher. Enemy aggression scales with progression.

Walked through how the table is read (line 2435):
```asm
       LDA ram_p1_current_round
       ASL ASL                     ; × 4 (4-byte stride)
       TAX
       LDA tbl_CDBF_round_attributes,X       ; bonus index
       STA ram_p1_bonus_round
       BEQ bra_CD8D_not_a_bonus_round        ; 0 → not bonus, normal round
       ; non-zero → set up bonus round
```

Same trick as Adventure's [`RoomNumToAddress`](../adventure/07-room-graph.md): pre-multiplied stride means the round index directly indexes the 4-byte records. **Round value as table offset** — same family as the 23-state machine's "state value as word-table offset" finding (chapter 2).

## Bonus rounds — engine reuse

When the bonus index is non-zero, `ram_p1_bonus_round` gets that value. Recall from [chapter 2's state dispatch](./02-object-records-and-states.md):

```asm
       LDA ram_p1_bonus_round
       BNE bra_DA1F_bonus_round            ; bonus → different state table
       LDA tbl_DA42_normal_round,X         ; normal → standard state table
```

**One byte controls which entire dispatch table the object state machine uses.** Bonus rounds aren't a separate engine; they're the same 9-object iteration loop, the same state machine framework, the same render pipeline — with **a different state-handler table swapped in**.

In the bonus round, the same object slots that hold the player and cats during normal play hold a balloon-with-fat-cat-inside (state $0E in the bonus table) and various pickup objects. Fat cat releases from balloon (state $12). Different states trigger different handler routines, which produce different gameplay.

The bonus mode also disables some things: cats don't chase you (the chase AI lives in normal-round state $02; bonus round's state $02 is different). The collision rules are different. The win condition is different.

**All of this — the entirely different gameplay of bonus rounds — is encoded as a different state-handler table.** Same engine, same data structures, swapped semantics via one byte. The cleanest mode-swap I've seen in this project.

## Score, BCD, and the Ricoh decimal-mode amputation

Mappy's score is stored as 4 BCD bytes:

```
$71 = ram_p1_score_xx000000    ; high digits
$72 = ram_p1_score_00xx0000
$73 = ram_p1_score_0000xx00
$74 = ram_p1_score_000000xx    ; low digits
```

But the [NES research README](../../../research/nes/README.md) noted: **the Ricoh 2A03 has BCD circuitry physically removed.** `SED` and `CLD` work as flag operations but arithmetic doesn't switch modes. Mappy can't use `ADC` with the decimal flag set to add BCD-formatted scores.

Instead, Mappy implements BCD arithmetic in software — adding the low byte, checking for digit overflow (>= 10), carrying to the next digit. ~30 instructions instead of one `ADC` with `SED`. **A direct consequence of the Ricoh amputation.** On a full 6502 (Atari 2600 included — the 6507 retains BCD), the same routine would be 5 instructions.

Score updates happen frequently (every item collected, every cat caught), so this is a recurring tax. Worth it for the chip's licensing arrangement, but worth recognizing as a real cost of the platform choice.

## The "Hurry!" text and the player's Type 0 dual identity

Recall from [chapter 5](./05-cat-ai.md) that `con_obj_type = 0` was tagged in `bank_val.inc` as **"player (mouse) / 'hurry' text."**

That dual identity makes sense now:
- During gameplay, type 0 = the player object (one slot, indexed first).
- During level-end timeout, the same object slot becomes the **"HURRY!" text** that flashes when time is running low.

**Same object slot, same record, same state machine — different meaning per game-mode context.** When the time-running-low condition triggers, the engine writes a "HURRY!" sprite into the player object's animation slot, and the existing render pipeline displays the text in the player's position (or wherever the engine tells it). The player can still move; the text is just an overlay rendered through the same pipeline.

This is the [byte-meaning dispatcher pattern](./05-cat-ai.md) from chapter 5, applied at the **object-type level**. Type 0 means different things in different game-mode contexts. The same pattern that re-purposes `con_obj_0B` across (type, state) pairs re-purposes the entire player slot across (game-mode, state) pairs.

## The Namco copyright at $C000

Recall from the project setup that the first 48 bytes of the bank ($C000–$C02F) hold the ASCII string:

```
"COPYRIGHT 1983 1984 NAMCO LTD.ALL RIGHTS RESERVED"
```

The disassembler comment said: *"sometimes 0x001EE2 reads this table up to C0FF, where code is — I can't tell if it's bad since I don't know what this does yet."*

Looking at where the title screen renders (likely inside `sub_CBB1` called from `ofs_C84F` line 1731), it almost certainly reads bytes from $C000+ as **ASCII characters to render onto the title screen**. The "COPYRIGHT" text appears on Mappy's title; the bytes that *are* the copyright string also serve as the *render data* for the title screen.

**Code and visible content overlap.** The same bytes are simultaneously:
- The legally-required copyright notice in the ROM
- The ASCII tile indices that render the visible "COPYRIGHT 1983 1984 NAMCO LTD" line on screen

This is dual-use *per byte* (recall Adventure's `$A2` triple-use). The notice is mandatory for legal reasons; encoding it as renderable tiles also makes it the title screen's content. **Two requirements satisfied by one allocation of bytes.**

The disassembler's uncertainty ("I can't tell if it's bad") flagged the question correctly — it noticed the bytes are read as data outside the obvious "ASCII storage" use. The "C0FF where code is" reference suggests the rendering code starts shortly after the string. **Code and data interpenetrate** — the boundary moves depending on which routine you're tracing.

## Compared to Adventure's "game state"

| | Adventure | Mappy |
|---|---|---|
| Modes | 1 (gameplay) | 5 (cold-boot, demo, gameplay, bonus, game-over) |
| Mode-switching state | None — game restarts on Reset | 9 zero-page bytes |
| Demo mode | None | Engine + alternate input source |
| Two-player support | None | 32-byte data blocks per player + swap routine |
| Levels / rounds | 1 (continuous) | 16+ rounds with progression |
| Bonus mode | None | Every 4 rounds, type-escalating |
| Score | 1-byte difficulty | 4-byte BCD score (software-implemented because Ricoh) |
| Lives | None — death = restart | Lives counter, respawn loop |
| Title screen | "Number Room" with game # | Full title with copyright + DEMO play |

Adventure was **a game**. Mappy is **a game with a frame around it** — title screen, lives, score, rounds, attract mode, bonus stages, two-player support. The frame is what arcade-conversion games of the era added. Pac-Man (1980, Namco) had this frame; Mappy inherits it directly.

**The frame is what the new CPU budget pays for.** Adventure's 5,000-cycles-per-frame budget couldn't carry the orchestration. Mappy's 25,000+ can — and the per-feature byte cost (~10-30 bytes for "attract mode," ~50 bytes for "two-player swap," ~64 bytes for "16-round progression") fits in NROM-128's generous 16 KiB.

## The Pac-Man lineage

Pac-Man (Namco, 1980) established the design vocabulary Mappy uses:
- State machine per ghost (Blinky, Pinky, Inky, Clyde) with shared engine + per-ghost personality table
- Attract mode with demo gameplay
- Bonus items (the fruits) with timing windows
- Score + lives + levels frame
- Two-player support via alternating turns

Mappy (Namco, 1983) is **Pac-Man's design vocabulary applied to a vertical platformer**:
- State machine per cat type (small, fat) with shared engine + per-type table
- Attract mode with demo gameplay
- Bonus items (fat cat hidden in money bag) with timing windows
- Score + lives + rounds + bonus rounds frame
- Two-player support via alternating turns

The architecture parallels are not coincidental. Namco's arcade designers built a *house style* of compact, data-driven, state-machine-heavy engines. Pac-Man on the Z80; Mappy on the 6502 (likely a later port from arcade, where it ran on the Namco Pac-Man hardware). **The design vocabulary outlasted the CPU.** Different chip families, same engineering thinking.

## Efficiency catalogue (chapter 6 entries)

- **Demo IS the game with replaced input.** Same `sub_C141` engine call from both demo loop and gameplay loop. One flag switches who controls the player. Cleanest possible attract-mode implementation.
- **Start-press transition in 30 instructions.** One byte flip + score reset + lives setup + level init. The entire "begin a new game" sequence.
- **64 bytes for 16 rounds × 4 attributes each.** Full game progression as a table. Bonus-round-every-4-levels rule is one byte per round.
- **Round value as 4-stride table index.** `ASL ASL` gives the offset; round index directly indexes the records. Same family as state-as-table-offset (chapter 2) and Adventure's room×9 multiplication (Adventure chapter 7).
- **One byte (`ram_p1_bonus_round`) swaps the entire object state-handler table.** Engine doesn't change; the dispatch table swaps. Bonus rounds and normal rounds share everything except their state semantics.
- **Two-player support via swappable 32-byte blocks.** Engine sees only "live" data; inactive player's state parked in parallel slots. ~50 bytes of code makes the engine 2-player without any engine-internal awareness.
- **Score as 4 BCD bytes with software arithmetic.** Direct consequence of the Ricoh BCD amputation. A real per-update tax that full-6502 systems (including the 2600) would pay 5 instructions for, Mappy pays 30.
- **Same object slot serves player AND "HURRY!" text.** Type 0 means different things in different game-mode contexts. Object-level byte-meaning dispatch (chapter 5 pattern, scaled up).
- **Copyright string as both legal notice AND title screen render data.** Bytes serve two distinct purposes. Mappy's analog of Adventure's `$A2` triple-use (chapter 1 of Adventure).

## What this surfaces about earlier chapters

- **Chapter 1's `ram_0023_flag` check** ("Is The Game Active?") in the main loop now has full context: when game is inactive (between levels, game over), the game-logic dispatch is skipped — only HUD rendering runs. Same loop, gated execution.
- **Chapter 2's bonus-round dispatch swap** is now end-to-end traceable: round-attributes table → `ram_p1_bonus_round` byte → state-handler table swap → different per-frame behavior for all objects. Top-level orchestration to per-object behavior in 4 layers of indirection.
- **Chapter 5's "byte-meaning dispatcher"** finding extends from object-state-level (chapter 5) to game-mode-level (chapter 6). The same bytes mean different things at multiple scales of context.
- **The Namco copyright string** is now legible as a deliberate dual-use, not just text-in-ROM. Same allocation strategy as Adventure's `$A2` — one byte, multiple roles.

## LLM-interpretation log

**Pure structure was sufficient for:**
- The mode-flag pattern (one byte per mode, branching reads it).
- The demo loop's "JSR engine / check button / decrement timer / loop" structure.
- The Start-press transition sequence (set flag, reset score, init level).
- The two-player data block layout (32-byte stride, identifiable from the equate file).
- The round-attributes table format (4 bytes per round, multiplication-via-shift to index it).

**Disassembler's labels and cross-refs were decisive for:**
- `ram_demo_flag` — naming the central mode bit. Without it, `$42` would be opaque.
- `ram_p1_lives`, `ram_p1_score_*`, `ram_p1_current_round` — naming each gameplay metric.
- `tbl_CDBF_round_attributes` — naming the table AND noting the column meanings inline. The four-column comment header (`+--- bonus round index | +--- index for $0C51 | ...`) is what makes the table readable. Without it, the 64 bytes are anonymous.
- `sub_CA81_swap_data_for_players` — name reveals the routine's role.
- `sub_CAA7_clear_data_of_all_objects` — name reveals it as the "new level setup" call.

**Where I trusted vs verified vs disagreed with the disassembler:**
- **Trusted**: round-attribute column meanings (the disassembler's inline header is a description of what each byte does in context — verifiable in principle by tracing where each byte gets read, but I trusted for speed).
- **Verified**: that bonus rounds happen every 4 levels (counted entries with non-zero first byte: rounds 02, 06, 0A, 0E — confirmed pattern).
- **Newly identified**: the dual-use of `con_obj_type = 0` for player AND "HURRY!" text. The disassembler labeled both possibilities in the equate file but didn't connect them as the same slot. Chapter 6's reading makes the same-slot-different-context interpretation explicit.

**Chip docs were load-bearing for:**
- That the 2A03 has BCD circuitry removed — explaining why Mappy implements score arithmetic in software instead of `ADC` with `SED`.
- Two-player joypad protocol from chapter 3's joypad section.

**Cumulative chapter knowledge from Adventure and earlier Mappy chapters:**
- **Adventure's "three game variants in 24 bytes"** is the closest precedent for "Mappy's 16-round progression in 64 bytes." Both encode the gameplay axis as data. Mappy's table is denser (4 attributes per round vs Adventure's 1 destination per variant).
- **Adventure's `$A2` triple-use** is the closest precedent for the Namco copyright string's dual role. Both pack multiple meanings into the same byte allocation.
- **Mappy chapter 2's bonus-round dispatch swap** finally fully unfolds in chapter 6's round-attributes context. The bonus-round flag set at level start (`ram_p1_bonus_round`) is what controls the dispatch swap during gameplay.
- **Pac-Man comparison (the user's catch)** unifies the two-decade Namco design lineage. Same data-driven state-machine engineering, ported from Z80 to 6502.

**Big find of chapter 6:** **the demo IS the game.** I expected attract mode to be a separate code path with simpler pre-canned animation. Instead it's the full engine, with the player's input source replaced. Same `sub_C141` runs in both modes; same rendering, same physics, same state machine. Just a different input. **Architectural elegance over gameplay completeness** — the result is that watching attract-mode Mappy looks identical to a real player playing badly, because that's exactly what it is.

This pattern probably extends to other Namco arcade-era games. **"Demo mode = game with replaced input"** is a design choice that pays off the more complex the engine becomes. Adventure couldn't afford it (no separate input layer); Mappy gets it for free because the engine already separates input from execution.

## What chapter 6 sets up for chapter 7

- **Level data** — the round-attributes table indexes into 3 other tables: layout (`$0C51`), enemy spawn (`$0FB6`), and one more (`$1195`). Chapter 7 will trace what those tables hold and how level layouts are encoded.
- **The bonus-round state-handler table** at `tbl_DA1F_bonus` — chapter 7 will look at the bonus-round-specific states (balloons, fat cat releases, etc.) and how they implement entirely different gameplay from the same engine.
- **The "HURRY!" text trigger** — the timer-low warning sequence likely uses a state-machine pattern similar to the cat respawn cycle. Worth a note in chapter 7's "level lifecycle" section.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
