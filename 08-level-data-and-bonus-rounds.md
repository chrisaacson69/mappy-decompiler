---
status: active
created: 2026-04-26
---
# Mappy — Level Data & Bonus Rounds
> The finale. Levels aren't one data structure — they're a stack of independently-indexed layers (palette, mansion layout, item placement, enemy spawn, blinking platforms). Bonus rounds reuse the engine through a swapped state-handler table — same objects, different gameplay.

**Links:** [Mappy README](./README.md), [Game State](./06-game-state.md), [Object Records & States](./02-object-records-and-states.md), [PPU Pipeline](./03-ppu-pipeline.md), [Adventure Room Graph (comparison)](../adventure/07-room-graph.md), source: [`raw/mappy_bank_FF.asm`](../../../raw/mappy_bank_FF.asm)

## What "level data" means in Mappy

Adventure's level system was a single 9-byte-per-room table with `$80`-flagged adjacency entries pointing at a 24-byte `RoomDiffs` override block (chapter 7 of Adventure). One unified data structure, three game variants encoded as overrides.

**Mappy's level system is a stack of independently-indexed layers.** Each round selects a different combination from each layer:

| Layer | What it controls | Indexed by |
|---|---|---|
| Palette / HUD template | Title screens, score header, B&W vs color | Round attribute byte 1 (chapter 6's `tbl_CC41` index) |
| Mansion floor layout | Static walls, floors, doors, windows | Round attribute byte 1 (different table) |
| Item placement | Where money bags / bells / pickups appear | Round attribute byte 2 |
| Enemy spawn config | How many cats, which types, spawn positions | Round attribute byte 2 |
| Trampoline configuration | Position, initial color, count | Inferred from layout + round number |
| Blinking platforms | Rounds 11-13 only | Computed from round number |
| Bonus round data | Balloons + fat cats (rounds 2/6/10/14) | Round attribute byte 0 (bonus index) |

**Per-round, Mappy can mix-and-match these layers** — same mansion layout with different enemy mix; same item placement with a different palette; etc. Adventure's "three game variants in 24 bytes" was monolithic — change variants, change everything. Mappy's per-round attribute bytes give finer control.

## The mansion as nametable data

The mansion's static structure (floors, walls, doors, windows, chains visible behind windows) is **rendered at level transition via direct PPUDATA writes**. Recall from [chapter 3](./03-ppu-pipeline.md) that `sub_C78E_write_data_to_buffer` has a runtime-selected dispatch:

- If rendering is OFF → write directly to PPUDATA (fast, used during level setup)
- If rendering is ON → queue into `ram_ppu_buffer_1` for next VBlank drain

During level transition:
1. Disable rendering (`sub_C241_disable_rendering` — PPUMASK = 0)
2. Walk a sequence of "draw command" tables (counter + PPU address + tile data, just like the buffer-1 format)
3. Each command writes a strip of mansion structure to the appropriate nametable region
4. Re-enable rendering (`sub_C239_enable_rendering` — PPUMASK = $1E)

The whole mansion is **a series of these draw commands**. The data tables I sampled earlier (`off_CC4B_00` for HI-SCORE header, `off_CC60_02` for palette init) are members of this same family. **Title screens, HUD, palettes, and mansion structure all use the same data format.**

This is the same architectural unification we saw repeatedly:
- Same engine handles player + cats (chapter 5)
- Same data format handles bonus + normal rounds (chapter 6)
- Same data format now handles HUD + palette + mansion structure

**One serialization, many uses.** The `[count][addr][data]` format is so general that it absorbs most level-load and transition work.

## Items live in the nametable

Recall from [chapter 3](./03-ppu-pipeline.md) and [chapter 4](./04-trampolines-and-physics.md): items (money bags, bells, etc.) are **background tiles**, not OAM sprites. Per-round item placement is therefore:
1. **A list of (tile-id, ppu-address) pairs** — write tile X at nametable position Y.
2. Generated as a sequence of `sub_C78E_write_data_to_buffer` calls during level setup.
3. Read back during gameplay via the [buffer-2 VRAM read-back](./03-ppu-pipeline.md) when player or cat steps on the tile.

When the player collects an item, the engine writes a "blank" tile to the same position via the buffer. The item visually disappears; the tile-id changes; future tile-under-foot reads return "blank" instead of "money bag tile."

**The level's item set IS the nametable's tile arrangement at level-start.** No separate "items collected" bitmask, no separate "items remaining" counter. Walk the nametable to count remaining items; absence of item-tiles = level cleared.

This is gameplay-state-as-render-state. **The thing on screen IS the gameplay state.** Adventure's items had separate (Room, X, Y) records in RAM; rendering followed from state. Mappy's items have only nametable presence; rendering IS state. Different abstraction, same outcome — but Mappy's removes a layer of indirection.

## Trampoline placement

Trampolines are special — they're **objects** (`obj_5` from chapter 4), not nametable tiles. Each trampoline has its own RAM-resident state (strength, animation timer, position) because it has dynamic state the nametable can't represent.

Per-round trampoline configuration sets the initial values:
- Position (X/Y on the screen, fixed per round)
- Initial strength (almost always 3 = yellow / fresh)
- Animation timer (0)

A `ram_obj_5_data` slot per trampoline. Mappy's mansions typically have 4-6 trampolines per level, all visible from the start. **The trampolines don't move; the player navigates around them.**

When a trampoline breaks (strength wraps from 0 to $FF, [chapter 4](./04-trampolines-and-physics.md)), its tile is updated to a "broken trampoline" graphic via the buffer-1 update queue. Same mechanism as item collection — change the tile, change the visual, change what the engine reads.

## Blinking platforms — the late-game cruelty

Rounds 11, 12, 13 introduce **blinking platforms** — sections of floor that periodically vanish, dropping anything standing on them.

From `sub_F001_prepare_platform_data` (line 8751):

```asm
sub_F001_prepare_platform_data:
       LDA ram_p1_current_round
       ASL                       ; round × 2
       SBC #$15                  ; subtract $15 (offset)
       CMP #$06                  ; in range 0..5?
       BCS bra_F040_RTS          ; no — no blinking platforms this round
       
       ASL                       ; multiply by 2 again (4 bytes per platform pair)
       TAX
       LDY #$00                  ; 1st platform slot
       JSR sub_F013_prepare_data
       LDY #$08                  ; 2nd platform slot
       JSR sub_F013_prepare_data
       RTS
```

The math:
- For round R: `R*2 - $15 < 6`
- Rearranging: `R < ($15 + 6)/2 = $1B/2` — but only positive results pass `BCC` (otherwise SBC borrows and gives a high value)
- So R must be in the range where `R*2 ≥ $15 + carry` and the result is `< 6`
- Working through: R = $0B → $16 - $15 = $01 ✓; R = $0C → $18 - $15 = $03 ✓; R = $0D → $1A - $15 = $05 ✓; R = $0E → $1C - $15 = $07 ✗ (also a bonus round so blinking would conflict)

**Rounds 11-13 (0x0B-0x0D) have blinking platforms.** Round 14 (0x0E) doesn't (bonus round). The check is one comparison, computed from the round number.

The platform itself is implemented as `obj_4` slots — the engine has a dedicated object type for "thing at a fixed PPU address whose tile changes periodically." Each blinking platform has:
- PPU address of its tile
- A state byte (0 = solid, 2 = blinking)
- Animation logic that swaps between "platform tile" and "empty floor tile" every few frames

The platform tiles flash via `sub_F04D_draw_platform_tiles`:

```asm
sub_F054_draw_tiles:
       LDA ram_obj_4_state,Y
       BEQ bra_F040_RTS          ; solid platform — no flicker
       CMP #$02
       BCC bra_F09C_01
       BNE bra_F088_03
       ; state $02 — blinking
       LDA ram_frm_cnt
       AND #$03
       CMP #$02
       BNE bra_F040_RTS          ; only update on frame % 4 == 2
```

**Update only on every 4th frame** (the `AND #$03 / CMP #$02` check). The blink rate is 60Hz / 4 = 15Hz. Fast enough to be jarring, slow enough that the player can time their jumps — but only if they're watching the platform's color.

Same wave-color trick from [chapter 5](./05-cat-ai.md) — derive temporal variation from `ram_frm_cnt` instead of maintaining per-object timers. **The frame counter is the universal animation clock for all visual variation.**

## Bonus rounds — the engine, repurposed

Recall from [chapter 6](./06-game-state.md) that bonus rounds happen on rounds 2, 6, 10, 14 (every 4th round, escalating type). They're triggered by `ram_p1_bonus_round != 0`. And from [chapter 2](./02-object-records-and-states.md), the bonus flag swaps the entire object state-handler dispatch table:

```asm
       LDA ram_p1_bonus_round
       BNE bra_DA1F_bonus_round         ; bonus → tbl_E17A_bonus_round
       LDA tbl_DA42_normal_round,X      ; normal → 23-state machine
```

The bonus dispatch table (`tbl_E17A_bonus_round` at line 6138) is **smaller than the normal one — only 10 entries**:

```asm
tbl_E17A_bonus_round:
       .word ofs_002_C14F_00_RTS                                ; $00 — no-op
       .word ofs_002_E19D_02                                    ; $02 — bonus walking state
       .word ofs_002_E19C_04_RTS                                ; $04 — no-op
       .word ofs_002_E200_06                                    ; $06 — ?
       .word ofs_002_E230_08                                    ; $08 — ?
       .word ofs_002_E2A1_0A                                    ; $0A — ?
       .word ofs_002_E2AC_0C                                    ; $0C — ?
       .word ofs_002_E2EE_0E_blue_balloon_with_fat_cat_inside   ; $0E — balloon!
       .word ofs_002_E2E0_10                                    ; $10 — ?
       .word ofs_002_E339_12_fat_cat_released_from_balloon      ; $12 — release!
```

**Same engine, different state semantics.** The 9-object iteration loop runs identically. Each object's state byte indexes the swapped table. The handlers do completely different things — `ofs_002_E2EE_0E_blue_balloon_with_fat_cat_inside` renders a balloon containing a fat cat instead of a normal walking cat or pickup item.

### The bonus round gameplay

In bonus rounds:
- The mansion structure changes (different layout — `tbl_CC41` index from round attributes)
- All "items" become **blue balloons**
- Each balloon has a **fat cat trapped inside**
- Cats don't chase the player
- The player's job: **collect balloons before the timer runs out**
- Each balloon collected releases the fat cat (state $0E → $12), which scampers away
- More balloons collected = more bonus points

The "fall through floor" mechanic at `sub_E18E_write_player_data`:

```asm
ofs_002_E19D_02:                  ; bonus state $02 — walking
       LDY #con_obj_08
       LDA (ram_001E_t04_object_data),Y    ; tile under foot
       SEC
       SBC #$49
       CMP #$07
       BCC bra_E18E_fall_through_floor    ; tile in range $49-$4F → fall through
```

In bonus rounds, **certain floor tiles drop the player to the floor below**. The player has to navigate using these intentional floor gaps to reach all the balloons in time. Same tile-under-foot mechanic from chapter 4, applied to a **different gameplay rule**: in normal rounds tile $49 = trampoline; in bonus rounds tile $49-$4F = fall-through floor.

**The same byte-meaning-dispatcher pattern from chapters 5 and 6**, scaled to game-mode level. Tile IDs mean different things per game mode.

### The balloon as a state-machine object

The balloon object exists in normal `obj_1` slots (positions $0410-$0490) but with bonus-mode state `$0E` (which only the bonus dispatch table interprets). Same record format, same iteration loop, same collision system — just runs the balloon-specific handler when state = $0E.

When the player overlaps a balloon (collision via the standard mechanism):
- State transitions $0E → $12 (released from balloon)
- The balloon graphic disappears (animation swap)
- The fat cat sprite appears in its place
- The fat cat object-record is configured for the bonus-specific "release and run" behavior

**No separate balloon-object code path.** The balloon IS an entry in the same object table as everything else; the bonus dispatch table makes it behave like a balloon. Switch to the normal table on a normal round, and the same slot would behave like a cat or item.

This is the cleanest demonstration of **mode-as-data** in the project. Adventure's mode-swap was via `$80`-flagged adjacency entries pointing at level-specific room destinations (chapter 7 of Adventure) — same room records, different adjacency. Mappy's mode-swap is via the dispatch table — same object records, different per-frame behavior. **Both encode mode as "swap one pointer, get a different game."**

## Per-round difficulty escalation

Looking back at [chapter 6's round-attributes table](./06-game-state.md):

| Round | Bonus | Layout idx | Enemy idx | Table-3 idx |
|---|---|---|---|---|
| 0 | normal | 4 | 0 | 0 |
| 1 | normal | 8 | 0 | 0 |
| 2 | **BONUS 2** | 4 | A | A |
| 3 | normal | 6 | 2 | 2 |
| 4 | normal | 4 | 2 | 2 |
| 5 | normal | 8 | 2 | 2 |
| 6 | **BONUS 4** | 4 | A | A |
| 7 | normal | 6 | 4 | 4 |
| ... | | | | |
| 11-13 | normal | (with blinking platforms) | 6 | 6 |
| 14 | **BONUS 8** | 4 | A | A |

The pattern, decoded:
- **Layout cycles**: 4, 8, 4, 6, 4, 8, 4, 6 ... three layout templates rotated to keep visual variety.
- **Enemy / table-3 indices grow with round**: 0 → 2 → 4 → 6 ... enemies get harder/more numerous.
- **Bonus rounds always use enemy/table-3 = A** — a special configuration that sets up balloons instead of cats.
- **Bonus rounds always use layout 4** — same template; balloons are spawned over it.

**The escalation curve is deliberate.** Layouts cycle to prevent staleness; enemy difficulty marches up; bonus rounds appear at predictable intervals as breathers. **Game design as data table — exactly the way modern games encode level progression**, just in 64 bytes instead of 64 megabytes.

The data IS the game design. **Mappy's level designer didn't write a level engine; they wrote 64 bytes of attributes.** The engine reads them and produces 16 distinct rounds. Want to add a round? Add 4 bytes. Want to rebalance the difficulty curve? Edit the enemy index column. **The game's content is data; the engine is reusable infrastructure.**

This is the modern game-design separation of "engine vs content" — and Namco was doing it in 1983.

## Compared to Adventure's level system

| Aspect | Adventure | Mappy |
|---|---|---|
| Level structure | 31 rooms × 9-byte records | 16 rounds × 4 attribute bytes |
| Variety mechanism | $80-flagged adjacency overrides for 3 game variants | Per-round indices into 3+ data tables |
| Static mansion data | Room graphics in CHR-ROM, drawn once per room visit | Mansion in nametable, drawn once per round |
| Items | (Room, X, Y) records in RAM | Tiles in nametable |
| Item collection | Set carry-pointer; positions follow player | Write blank tile to nametable; visual disappears |
| Per-round difficulty | Difficulty switches change dragon flee behavior | Round number drives dragon-equivalent (cat) spawn config |
| Hidden levels | Easter egg room ($1E), unreachable normally | None (all 16 rounds reachable in sequence) |
| Bonus mode | None | Every 4 rounds, separate dispatch table |
| Endless | Yes (you can stay in the kingdom forever) | Yes (round 15 → loop back to 0?) |

Adventure's level system was **monolithic but variant-able** — one game with three configurations.

Mappy's level system is **modular and round-progressive** — a sequence of rounds, each independently parameterized.

Both encode their entire level structure in 24-64 bytes of data. **Both refused to use ROM space for redundant level encoding.** The lessons of compact data design ported forward; only the *axis* of variation changed.

## Efficiency catalogue (chapter 8 entries)

- **Level data is layered**: palette, mansion, items, enemies, trampolines, blinking platforms, bonus mode — each independently indexed, each round combines them differently.
- **Mansion drawn via the same `[count][addr][data]` format** as palette init, HUD, and runtime PPU updates. **One serialization for everything that touches the nametable.**
- **Items live as nametable tiles, not RAM records.** No separate items-remaining counter; the nametable IS the gameplay state.
- **Blinking platforms via `obj_4` slots** with PPU addresses, state-driven tile swap on `ram_frm_cnt AND #$03 == 2`. Update rate ~15Hz. **Frame counter is the universal animation clock.**
- **Bonus dispatch table is half the size** of the normal-mode table (10 vs 23 entries). Bonus rounds don't need all the platformer states — no jumping arcs in balloon-collecting mode.
- **Tile IDs mean different things per game mode**. $49 = trampoline in normal; $49-$4F = fall-through floor in bonus. **Same byte-meaning-dispatcher pattern as chapters 5/6, applied to tile semantics.**
- **The blinking-platform check is one comparison.** `LDA round / ASL / SBC #$15 / CMP #$06 / BCS bail` decides whether the round has blinking platforms. Round 11/12/13 = yes; everything else = no. **Per-round feature flags computed from the round number, no per-round table entry.**
- **The escalation curve is data, not code.** Enemy difficulty, layout selection, bonus pacing — all encoded in 64 bytes. The engine is round-agnostic.

## What this surfaces about earlier chapters

- **Chapter 3's "background as sprites"** is now end-to-end: items live in the nametable; collection is a tile change; collision is a tile read. **The nametable is the game's primary state grid.**
- **Chapter 4's tile-under-foot mechanic** generalizes beyond trampolines: the same engine, same buffer-2 read-back, different rules per game mode.
- **Chapter 5's byte-meaning-dispatcher pattern** keeps generalizing: state-context (chapter 5), object-type-context (chapter 5), game-mode-context (chapter 6), now **tile-semantic-context (chapter 8)**. The same pattern at every scale.
- **Chapter 6's round-attributes table** is now fully traceable: 4 bytes per round → 4 different data layers → an entire level rendered, populated, and gameplay-tuned.
- **Chapter 2's bonus-mode dispatch swap** comes full circle: chapter 8 shows what the bonus mode actually IS (balloon collection with different tile semantics), and that the swap is the entire mechanism.

## LLM-interpretation log

**Pure structure was sufficient for:**
- The "draw command" data format (`[count][addr_lo][addr_hi][data...]`).
- The `obj_4` slot pattern for blinking platforms (struct of (state, ppu_addr, position)).
- The bonus dispatch table as a parallel to the normal one (same indirect-jump pattern, different table).
- The blinking-platform round check (`LDA / ASL / SBC / CMP / BCS`).
- The 4-frame animation gating (`LDA frm_cnt / AND #$03 / CMP #$02`).

**Disassembler's labels and cross-refs were decisive for:**
- `sub_F001_prepare_platform_data` — name reveals the routine's role.
- `tbl_E17A_bonus_round` and `ofs_002_E2EE_0E_blue_balloon_with_fat_cat_inside` — the bonus mechanic is named in the labels.
- `tbl_F128_platform_tiles` — naming the visual data for the blinking-platform animation.
- `con_bonus_state_*` — naming the bonus-state semantics.
- `tbl_CDBF_round_attributes` with its **inline 4-column header comment** — the single most useful annotation in the entire disassembly. Without that header, decoding the round-attributes table would have taken a chapter on its own.

**Where I trusted vs verified vs disagreed with the disassembler:**
- **Trusted**: bonus-state names ("blue_balloon_with_fat_cat_inside" — game-flavor, can't verify from source).
- **Verified**: blinking-platform rounds = 11-13. Worked the math: `round*2 - $15 < 6` → R in {$0B, $0C, $0D}.
- **Verified**: 10 entries in the bonus dispatch table (counted `.word`s).
- **Newly identified**: tile $49-$4F = fall-through-floor in bonus mode (was vague before; chapter 8 pinned it down).

**Chip docs were load-bearing for:**
- That nametable updates require either rendering-off or buffer-1-via-VBlank — explaining the level-load `disable rendering / write data / re-enable` pattern.
- That CHR-ROM is fixed for NROM (mansion graphics can't be swapped mid-game; rounds reuse the same tile patterns).
- The 8x8 tile resolution → mansion features must align to 8-pixel grid.

**Cumulative chapter knowledge:**
- **Adventure's "level data as compact configuration"** (chapter 7 of Adventure) and **Mappy's "level data as layered indices"** are different solutions to the same problem: encode game design without using up ROM. Adventure used overrides; Mappy uses cross-products. Both fit in tens of bytes.
- **Every previous Mappy chapter's "byte-meaning depends on context"** finding compounds into chapter 8's "tile semantics depend on game mode." The pattern operates at every scale: byte → state context, byte → object-type context, byte → game-mode context, tile-id → game-mode context. **The chip's address space is one big polymorphic system; what bytes mean depends on who's reading them and when.**

**Big find of chapter 8:** **the engine vs content separation.** Mappy's 16 rounds are 64 bytes of round-attributes pointing at multiple data tables. The engine doesn't know about rounds — it reads the attributes, fetches indexed configurations, runs the universal object loop. **Game content as pure data; engine as reusable infrastructure.** This is exactly how modern games separate engine from content; Namco did it in 1983 because they had to (ROM was expensive) and it scaled (ports to other platforms reuse the engine layer).

**The series-wide finding:** Adventure (1980) and Mappy (1983) are both **ruthlessly economical** with their data structures. Both encode entire game systems in tens of bytes. Both prove that **constraint breeds elegance** — the discipline of a 4 KB / 16 KB ROM forced architectural choices that are still relevant for game engines today. The genres they invented (action-adventure, platform-with-traversal-mechanic) are direct consequences of what their hardware allowed and their programmers extracted.

## The series, complete

Mappy's eight chapters cover:

1. **Reset & frame structure** — NMI vs WSYNC, main-loop polling pattern, the storytelling-vs-logic axis quantified at 5× more game-logic CPU time per frame.
2. **Object records & states** — 9 objects × 16 bytes, 23-state machine via word-table indirect jump, bonus dispatch swap.
3. **PPU pipeline & background-as-sprites** — OAMDMA, dual buffers, single-API enqueue with deferred/immediate dispatch, garbage NOPs as audio-timing safeguards, plus the fully-convoluted joypad subsystem.
4. **Trampolines & physics** — bounce as a 6-state machine, tile-under-foot collision via VRAM read-back, 3-instruction asymmetric "cats don't wear out trampolines" rule.
5. **Cat AI & doors as weapons** — fat cat hides in items for bonus, multi-cat combo via per-cat door reference, the byte-meaning-dispatcher finding.
6. **Game state & mode orchestration** — demo IS the game with replaced input, 16 rounds in 64 bytes, two-player swappable data blocks, Pac-Man design lineage.
7. **Music & sound engine** — 25-voice mixer with priority via slot order, the engine is small because the APU is large.
8. **Level data & bonus rounds** (this chapter) — layered level data, mansion as nametable, items as tiles, bonus mode as dispatch-swap, engine vs content separation.

**Cumulative finding across the series:** Mappy is **Pac-Man's design vocabulary applied to a vertical platformer** — same data-driven state-machine engine, same demo-mode-as-game-with-AI, same bonus-items-with-timing-windows. Different chip family (Z80 → 6502), same Namco engineering thinking. The 6502 era's compact engines weren't an accident of constraint; they were a design philosophy that **outlasted any specific CPU**.

Adventure forced design IS story (no spare cycles for narrative state). Mappy's freed CPU cycles (PPU autonomous, APU autonomous) afforded **storytelling-as-code**: continuous music, scripted demo, multi-round progression, bonus mode, two-player support. The frame around the game became as elaborate as the game itself.

**The same hardware-software co-design pattern that defined Adventure defines Mappy** — just at a different point in the trade space. Both spent every available byte and cycle on something the player would notice.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
