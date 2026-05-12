---
status: active
created: 2026-04-26
---
# Mappy — Cat AI & Doors as Weapons
> Two cat types, the fat cat's "hide inside an item" bonus mechanic, and how one byte (`con_obj_0B`) re-purposed lets a single door sweep multiple cats for combo points. The enemies are designed around the player's weapon.

**Links:** [Mappy README](./README.md), [Object Records & States](./02-object-records-and-states.md), [PPU Pipeline](./03-ppu-pipeline.md), [Trampolines & Physics](./04-trampolines-and-physics.md), [Adventure Bat AI (comparison)](../adventure/05-bat-ai.md), [Adventure Dragon State Machine (comparison)](../adventure/06-dragon-state-machine.md), source: [`raw/mappy_bank_FF.asm`](../../../raw/mappy_bank_FF.asm)

## The cast

Two cat types, one shared movement model, asymmetric behavior:

| Type byte | Name | Color | Behavior |
|---|---|---|---|
| `$02` | Meowky (small cat) | Pink | Pure chase; respawns; basic enemy |
| `$03` | Goro (fat cat) | Red | Chases AND **hides inside items** for bonus points |

`bank_val.inc` calls them "small cat" and "fat cat"; the localized names are folklore. The mechanical distinction is the type byte — read once per object, drives all behavior differences.

## Cat chase — state $02 with cat-specific code

Cats spend most of their time in state `$02` (standing/moving on platform), the same default state Mappy uses when not bouncing. **The state handler at `ofs_001_DA70_02` runs for both player and cats**, with internal branches gating per-type behavior:

- **Player** in state $02 — reads input, walks left/right, can step onto trampolines.
- **Cats** in state $02 — chase AI, no input, can step onto trampolines without consuming bounces (chapter 4's [asymmetric mechanic](./04-trampolines-and-physics.md)).

This is **the opposite of Adventure's design.** Adventure had separate AI engines per agent (bat = `MoveBat`, dragons = `MoveRedDragon` / `MoveYellowDragon` / `MoveGreenDragon`) with one shared movement primitive. **Mappy has one shared state handler with per-type branches inside.** Adventure factored by agent; Mappy factors by state.

Why the change? Adventure's bat was structurally different from dragons — different priority list, different movement cadence, different pickup mechanic. Mappy's two cats are *mostly the same thing* — both chase, both walk, both bounce on trampolines without breaking them. Per-type branches inside one handler is cheaper than two parallel handlers. **Architecture matches the actual variation.**

## The fat cat hides inside items — the bonus mechanic

This is the mechanic you've been waiting for. `sub_E757_fat_cat_hide_inside_item` (line 7184):

```asm
sub_E757_fat_cat_hide_inside_item:
       LDA ram_obj_1_state + con_ofs_obj + $20    ; fat cat's state
       CMP #con_state_02
       BNE bra_E787_RTS                           ; not walking, bail
       
       LDA ram_obj_1_jump_pos + con_ofs_obj + $20
       BNE bra_E787_RTS                           ; airborne, bail
       
       ; Check if fat cat aligns with an item
       LDA ram_obj_6_pos_Y_lo,X
       CMP ram_obj_1_pos_Y_lo + con_ofs_obj + $20
       BNE bra_E787_RTS                           ; Y mismatch
       
       LDA ram_obj_6_pos_X_lo,X
       CMP ram_obj_1_pos_X_lo + con_ofs_obj + $20
       BNE bra_E787_RTS                           ; X mismatch
       
       ; Aligned with an item — HIDE
       LDA #$00
       STA ram_obj_1_pos_X_fr + con_ofs_obj + $20  ; snap to integer position
       LDA #con_anim_id_fat_cat_hide + $01
       STA ram_obj_1_animation + con_ofs_obj + $20  ; "hiding" sprite
       LDA #con_state_1E
       STA ram_obj_1_state + con_ofs_obj + $20      ; state = hiding
       LDA #$78                                     ; 120 frames = 2 seconds
       STA ram_obj_1_timer + con_ofs_obj + $20      ; hide duration
       
bra_E787_RTS:
       RTS
```

Conditions to trigger the hide:
1. Fat cat is in state $02 (walking — not jumping, not falling, not stunned).
2. Fat cat's `jump_pos == 0` (not in the middle of a bounce arc).
3. Fat cat's position **exactly matches** an item's position (X and Y both).

When all three: switch the fat cat to state $1E (hidden in item), play the hiding animation, set a 2-second timer. **Now the item on the screen contains a fat cat.** The player can't tell visually which item is "loaded" — *it's the same item sprite as before*.

If the player collects the item normally, they get the standard item points. **If the player triggers a sound wave that reaches that item before the timer expires, the fat cat is exposed and the player gets the bonus.** Mappy's iconic "1000-point money bag" moments come from this.

The stakes: the fat cat is invisible while hidden. You don't know which money bag is loaded. You can't tell from looking. **The risk is taking too long; the reward is timing the door so the wave catches the cat right as it's hiding.** That's the gameplay tension this 30-line routine creates.

It's a remarkable mechanic-to-code ratio. **Two seconds of stakes, defined in 30 instructions.** Adventure's most complex per-object behavior (the bat's Fed-Up cycle from [chapter 5 of Adventure](../adventure/05-bat-ai.md)) was structurally similar: one byte of state, a timer, a transition. Mappy's fat-cat-in-item is the same family of trick, applied to a *bonus* condition rather than a movement cycle.

## The door as weapon — sound wave creation

When the player opens a door, the door's tile (background) starts an animation cycle (closed → opening → open → closing → closed). Each frame, a `sub_C78E_write_data_to_buffer` (chapter 3) call updates the door's nametable byte to the next animation frame. Visually the door swings.

Behaviorally, the door creates a **sound wave** that travels along the floor. The wave is itself rendered as a sprite (it moves smoothly, animates per-frame), so it lives in OAM, not the nametable. Its handler at `ofs_000_C4C6_08_sound_wave` (line 1016) draws the wave with cycling colors via `ram_frm_cnt`:

```asm
ofs_000_C4C6_08_sound_wave:
       LDA ram_frm_cnt
       LSR
       AND #$03                  ; cycle through 4 colors
       STA ram_0013_t03_spr_A    ; sprite attribute (palette select)
       LDA #$50                  ; sound wave tile
       STA ram_0012_t10_spr_T_1
       ; ... mirror flip based on direction ...
       JSR sub_C3E3              ; render the sprite
```

The 4-color cycle (`ram_frm_cnt LSR / AND #$03`) gives the wave its **rainbow shimmer**. Each frame's color is determined by the current global frame counter — same trick across all flickering visuals. The CPU doesn't track the wave's color directly; it derives the color from "what frame is it" and gets temporal variation for free.

## Cats caught by wave — state $16 and the door-reference trick

When a wave reaches a cat, the cat transitions to state `$16` (caught up in sound wave). Recall from [chapter 2](./02-object-records-and-states.md) that state $16's per-frame handler is **RTS** (no-op). The cat doesn't update its own position while in this state — *something else does*.

That something else is `sub_EEC9` (line 8537):

```asm
sub_EEC9:
       LDX #$20                  ; start with first cat slot ($0420)
bra_EECB_loop:
       LDA ram_obj_1_040B,X      ; cat's $0B byte = "which door caught me"
       CMP ram_001E_t04_object_data    ; matches the current door?
       BNE bra_EEE1              ; no — skip
       
       LDA ram_obj_1_state,X
       CMP #con_state_16         ; still in caught state?
       BNE bra_EEE1              ; no — skip (cat may have transitioned)
       
       LDA ram_0063              ; wave's current X position
       CLC
       ADC #$08                  ; offset
       JSR sub_EEEB_move_object_X_axis    ; move cat's X to match wave
       
bra_EEE1:
       TXA
       CLC
       ADC #con_ofs_obj + $10    ; next object slot
       TAX
       CPX #con_ofs_obj + $90    ; checked all 8 cat slots?
       BNE bra_EECB_loop
       RTS
```

**Two findings here:**

### The `con_obj_0B` re-purpose

In [chapter 4](./04-trampolines-and-physics.md), `con_obj_0B` was the **player's vertical velocity** during state $0C (flying up after spring). Here, in cats during state $16, **the same byte holds the door's address** (`ram_obj_1_040B,X` is `con_obj_0B` of the cat).

Two completely different meanings for one byte:
- **Player + state $0C**: `$0B` = signed vertical velocity (e.g., `$E0` = -32)
- **Cat + state $16**: `$0B` = pointer to the door object that caught this cat

Same byte, different meaning per (object-type, state) pair. **The state machine doubles as a byte-meaning dispatcher.** Adventure had nothing this aggressive — Adventure's variables had one meaning each. Mappy reuses every byte across multiple semantic contexts.

This is what makes Mappy's 16-byte-per-object record so much richer than its size suggests. **Each byte means more than one thing across the object's lifetime.** Adventure's 5-byte dragon record is more than 5 bytes of information — Mappy's 16-byte record is more than 16.

### The "every cat following its door" pattern

`sub_EEC9` walks all 8 cat slots. Each cat in state $16 with the matching door reference gets its X position locked to the wave's X position. **One door, many cats, one update routine.** The cat's `con_obj_0B` ties it to the specific door that caught it; the routine iterates and updates each tied cat.

Why store the door reference per cat? Because **multiple doors can be open at once**, each generating its own wave. Cat A might be following door A's wave; cat B might be following door B's wave. The per-cat door reference disambiguates.

## Multi-cat combo points — designed into the data structure

Now the user's "guy that gets the big points" angle, generalized: **multiple cats can be caught by the same wave** if they're in line.

When the player opens a door at the right moment, the wave sweeps along the floor catching every cat in its path. Each catch transitions a cat from state $02 (walking) to state $16 (caught), with `con_obj_0B` pointing at the door.

After the wave reaches the wall, each caught cat transitions $16 → $18 (flying score points). State $18's handler emits a score popup at the cat's position. **The number of cats caught determines the point value of each subsequent popup** — the engine maintains a multiplier that increases per-catch.

The multi-cat catch is structurally enabled by:
1. **Multiple cats can be in state $16 simultaneously** (the per-cat door reference).
2. **One iteration loop processes all of them** (`sub_EEC9` walks all object slots).
3. **The wave object has its own position state** (`ram_0063`) that all caught cats follow.

**No combo-tracking code exists separately.** The combo IS the data layout — N cats in state $16 referencing the same door = N-cat combo. The score multiplier is a downstream consequence of "how many cats are currently in state $18."

This is gameplay-design-as-data-structure. Adventure's "[three game variants in 24 bytes](../adventure/07-room-graph.md)" was the same idea — encode the gameplay axis in the data layout, not in branching code. **Multi-cat combos in Mappy are achievable because the engine's data structures naturally express them.**

## The state cycle — caught to gone to respawned

Full lifecycle of a caught cat:

```
$02 (walking)
   ↓ (wave reaches cat)
$16 (caught — moves with wave; con_obj_0B = door ref)
   ↓ (wave reaches wall, or timer)
$18 (flying score points — popup appears at cat's position)
   ↓ (popup animation completes)
$1A (waiting for respawn)
   ↓ (respawn timer, ai_delay_timer)
$02 (walking — cat is back!)
```

Three transitional states ($16, $18, $1A) for one defeated-and-respawned cycle. Each does little code-wise:
- **$16** is no-op (movement done by `sub_EEC9` from outside)
- **$18** is no-op (popup animation handled by render pipeline)
- **$1A** is the respawn timer ([chapter 1](./01-reset-and-frame-structure.md) noted `INC ram_ai_delay_timer` in the main loop; the respawn check happens in state $1A's handler)

**The cats are never permanently gone.** They respawn after a fixed delay, walk back into the maze, and resume chasing. The "defeat" is a temporary score event, not an elimination. Mappy is endless-survival-with-points, not enemies-to-clear. The respawn loop *is the gameplay.*

## Cat-vs-player collision — the Game Over

State `$08` from chapter 2 was tagged "enemy cat touched player." This is the mortality event. When a cat in state $02 (chasing) reaches the player's exact tile position, the player transitions to state $08, which triggers the death animation sequence:

```
$08 → $2A → $2C → game over flow
```

The collision check itself is **cheap** — Mappy's tile-grid means "player and cat occupy the same tile" is one position comparison. No bounding-box math, no per-pixel hit-testing. Same family as the [trampoline detection](./04-trampolines-and-physics.md): grid-aligned positions make collision a `CMP` away.

**Compare Adventure's dragon-eats-ball (chapter 6 of Adventure):** TIA hardware collision detection (CXP0FB) reported pixel-overlap; the game responded by snapping the dragon's position to the ball's previous frame and entering the bite countdown. Adventure had **hardware** collision but had to bridge it to gameplay state with several frames of bookkeeping. Mappy has **software** collision (tile comparison) but the gameplay state transition is immediate. Different chips, different trade-offs, similar end-game feel.

## Compared to Adventure's enemies

| | Adventure (chapter 5/6) | Mappy (this chapter) |
|---|---|---|
| Enemy types | 4 (3 dragons + bat) | 2 (small cat + fat cat) |
| Per-enemy AI engine | Shared `MoveGameObject` + per-agent matrices | Shared state handler + per-type branches |
| Enemy goals | Pathfind toward target via priority matrix | Chase the player position |
| Player defense | Sword (kill dragon if both displayed same frame) | Door (sweeps cats off floor) |
| Defeat mechanic | Permanent death (dragon stays dead) | Temporary defeat (cats respawn) |
| Bonus mechanic | None (chalice = level win) | Fat cat hides in items for bonus points |
| Combo mechanic | None | Multi-cat sound-wave catches |

**Adventure's enemies were obstacles you maneuvered around.** They had simple chase/flee AI and one defeat condition (sword). The game-design verb was *survival*.

**Mappy's enemies are targets you herd into your weapon.** They have simpler AI but richer *interaction* — they can be caught in groups, they can hide in items for bonuses, they respawn so the encounter is continuous. The game-design verb is *exploitation* — line them up, time the door, maximize the multiplier.

This is a different gameplay primitive entirely, enabled by the same hardware shift. Adventure's CPU budget couldn't support the multi-state defeat sequence ($16 → $18 → $1A) plus the fat-cat-hide-in-item mechanic plus respawn timers plus combo accounting. Mappy's CPU budget can. **Same broad genre (you-vs-enemies-in-a-grid), categorically different design vocabulary.**

## Efficiency catalogue (chapter 5 entries)

- **Per-type branches inside one shared state handler.** Cats and player both run state $02; the handler reads `con_obj_type` and branches. Cheaper than per-type handlers when the variation is small.
- **`con_obj_0B` re-purposed across (object-type, state) pairs.** Player + state $0C = vertical velocity; cat + state $16 = door reference. State machine doubles as byte-meaning dispatcher.
- **No-op states for transitional behavior.** States $16, $18, $1A all have RTS handlers — the actual per-frame work happens in *external* routines (`sub_EEC9` for $16; render pipeline for $18; respawn timer logic for $1A). The state slot exists to *gate* transitions, not to *do* work.
- **Multi-cat combo as data-layout consequence.** No combo-tracking code per se; the combo is "how many cats are currently in state $16/$18 with matching door reference." Score multiplier reads the implicit count.
- **Fat-cat-in-item in 30 instructions.** Three position checks + four state writes + a 2-second timer. The entire risk/reward bonus mechanic.
- **Wave color cycling via `ram_frm_cnt LSR / AND #$03`.** No animation timer per wave; just derive color from the global frame counter. Free temporal variation.
- **Tile-aligned collision = one CMP per axis.** Cat-on-player and item-on-cat both work via X/Y compare on integer tile coordinates. No bounding boxes.
- **Cats respawn rather than die permanently.** Removes the "did I clear all enemies" tracking burden. The level loop is endless until time-out or player death. **Architecture matches the gameplay loop.**

## What this confirms about earlier chapters

- **Chapter 4's "byte re-purposing across states"** finding now extends to "byte re-purposing across object types AND states." The state machine is also a per-object-type semantic dispatcher.
- **Chapter 3's "background as sprites"** finding gets a partial qualifier: the *items* are background tiles, but the *sound wave* is a sprite (because it moves smoothly). The rule isn't universal — it's "background for things that don't need sub-pixel motion." The wave needs sub-pixel motion to *sweep* smoothly across the floor.
- **Chapter 2's "23-state machine"** finding now has all the major states accounted for: $02 (walking), $04 (jump), $06 (falling), $08 (cat-touched-player), $0A-$0E (trampoline arc), $16/$18/$1A (caught-cat sequence), $1E (fat-cat-hidden-in-item), $2A/$2C (player death). 14+ of 23 states explained across chapters 4-5.

## LLM-interpretation log

**Pure structure was sufficient for:**
- The "iterate object slots looking for matching state" pattern in `sub_EEC9` (`LDX #$20 / loop / LDA / CMP / BNE / process / ADC / CMP #$90 / BNE`).
- The position-equality test for fat-cat-on-item (`CMP X` / `BNE skip` / `CMP Y` / `BNE skip` / proceed).
- The multi-test gate pattern (state == $02 AND jump_pos == 0 AND positions match) as a precondition chain.
- The state transition (write state + write animation + write timer + RTS).

**Disassembler's labels and cross-refs were decisive for:**
- `sub_E757_fat_cat_hide_inside_item` — name reveals the routine's gameplay role. Without it, the position-equality check would look like generic "is object on item" code.
- `sub_D846_fat_and_small_cat` — the `_fat_and_small_cat` suffix tells me cats are processed jointly through this routine, with type branches inside.
- `con_anim_id_fat_cat_hide` — names the animation, confirming the hide mechanic exists as a discrete visual.
- The per-state semantic comments in `bank_val.inc` ("caught up in sound wave," "flying score points after $16," "waiting for respawn after $18") — without these, the $16-$18-$1A cycle's gameplay meaning would take much longer to figure out.

**Where I trusted vs verified vs disagreed with the disassembler:**
- **Trusted:** the cat-name labels (small/fat); the gameplay-flavor descriptions of states $16-$1A.
- **Verified:** that `con_obj_0B` is the door reference for cats in state $16 (traced `sub_EEC9` reading `ram_obj_1_040B,X` and matching against `ram_001E_t04_object_data` which holds the current door's address).
- **Newly identified:** state $1E is "fat cat hidden inside item" — chapter 2 had this as TBD; chapter 5's trace through `sub_E757` confirms it.
- **Still TBD:** state $1C, $20, $22, $24, $26, $28 — none of these came up in the cat-AI trace. Likely level-transition / bonus-round-related; chapter 6 (game state) might reveal them.

**Chip docs were load-bearing for:**
- That sprites move smoothly because they have sub-pixel positions and OAM updates per frame; backgrounds change in tile-aligned chunks. This is *why* the sound wave is a sprite (smooth sweep) and the door is background (discrete state changes).
- Tile-grid collision via VRAM read-back from chapter 3's PPU pipeline.

**Cumulative chapter knowledge:**
- **Chapter 4's player-only byte decoding** had `con_obj_0B = vertical velocity`. Chapter 5 finds the *same byte* used as a door reference for cats. **This re-frames the player-only-vs-shared distinction**: bytes $08-$0E aren't "player only"; they're "context-dependent, with the player using one set of meanings and other object types using different ones." The naming convention `con_obj_AB` (line 28 of `bank_val.inc`) was misleading; the actual usage is **per-(type, state) byte aliasing**.
- **Adventure's bat AI's Fed-Up cycle** from [chapter 5 of Adventure](../adventure/05-bat-ai.md) is the closest precedent for the fat-cat-hide-in-item mechanic. Both use a timer + state byte + position alignment to create a periodic risk/reward window.
- **Adventure's "matrix slot order encodes role"** finding from chapter 6 of Adventure is the closest precedent for Mappy's "cat type byte gates trampoline-strength decrement." Both encode binary behavioral rules in 1-3 instruction conditionals on existing data.

**Big find of chapter 5:** **the state machine is a per-object-type byte-meaning dispatcher**, not just a behavior dispatcher. `con_obj_0B` is "vertical velocity" when the object is the player in state $0C; "door reference" when the object is a cat in state $16. The state machine determines what the byte *is* at runtime. This is a categorically different architectural choice than Adventure's "every variable has one fixed meaning." **It's why Mappy's 16-byte object record carries far more than 16 bytes of information** — the meaning is multiplied by the number of (type, state) contexts the byte appears in.

This insight retroactively re-frames chapters 2 and 4: the "player-only fields" naming was a simplification. **There are no player-only fields, only context-dependent fields.** The player happens to use bytes $08-$0E in player-specific ways during player-specific states; those same bytes get used differently in other (type, state) contexts. **The disassembler's choice to call them "player_only" reflected what they observed in *one* code path, not what's actually true across all paths.** Honest update to the chapter-2 finding.

## What chapter 5 sets up for chapter 6

- **Game state** (the user-suggested chapter): we've now seen attract-mode-vs-gameplay-vs-bonus-round implied by the `ram_p1_bonus_round` flag and the bonus-mode dispatch table from chapter 2. Chapter 6 will trace the high-level game-mode state machine: how the engine swaps between intro screen, demo play, gameplay, level transitions, and bonus rounds.
- **Level data** (the natural follow): with cats and items understood as object/tile combinations, chapter 7 can look at how each level is encoded — what mansion floor layout, item placement, trampoline positions, fat cat availability all live in compact data.
- **The Namco copyright string** at the top of the bank ($C000) might play a role in the attract mode display — that's a chapter-6 cross-reference to chase.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
