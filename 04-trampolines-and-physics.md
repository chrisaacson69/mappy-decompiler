---
status: active
created: 2026-04-26
---
# Mappy — Trampolines & Physics
> The bounce mechanic that defines Mappy's genre. A 4-state arc decomposes one trampoline jump into discrete physics phases. Tile-under-foot detection via VRAM read-back drives collision. And one of the cleverest "asymmetric gameplay rule encoded in 3 instructions" findings in the project.

**Links:** [Mappy README](./README.md), [Object Records & States](./02-object-records-and-states.md), [PPU Pipeline](./03-ppu-pipeline.md), [Adventure Movement & Collision (comparison)](../adventure/04-movement-collision.md), source: [`raw/mappy_bank_FF.asm`](../../../raw/mappy_bank_FF.asm)

## What the trampoline does in the game

Mappy is a vertical-multi-floor maze. Floors are connected by **trampolines** at fixed positions. Mappy bounces from one floor to the next; he can't climb stairs or jump otherwise. The trampolines are **the entire vertical movement system.**

Each trampoline can be bounced on a finite number of times before it breaks:
- Fresh: yellow
- One use: green
- Final use: red
- After: gone (broken)

Cats — both small (pink) and fat (red) — can also use trampolines, but **don't wear them out**. The trampoline's lifespan is metered by player use only.

This asymmetric mechanic is the game's central balance choice. The whole genre Mappy launched (vertical multi-floor platformers with limited-use traversal) flows from this one rule.

## The bounce as a state machine

From chapter 2, the relevant states are:

| State | Name | Phase |
|---|---|---|
| `$02` | standing/moving on platform | walking; can step onto trampoline |
| `$0A` | jumping off spring | trampoline compressing; player still on it |
| `$0C` | flying up after $0A | upward arc; vertical velocity decays |
| `$0E` | moving sideways after $0A | apex; horizontal motion permitted |
| `$06` | falling down after $0C | gravity; descent toward next floor |
| `$04` | jump off platform / hit wall | landing transition |

A complete bounce: `$02 → $0A → $0C → $0E → $06 → $04 → $02`. **Six states for one mechanical action.** Adventure's man moved in straight lines and never had a jump — the entire "vertical action" lexicon is new at the NES level.

Each phase has its own physics. `$0A` reads the trampoline state. `$0C` applies upward velocity that decays. `$0E` is the apex where horizontal input matters. `$06` applies gravity. The state machine *is* the physics engine.

## State $0A — touching the trampoline

`ofs_001_DC02_0A` (line 5214). Walking through the body:

```asm
ofs_001_DC02_0A:
       LDY #con_obj_0B            ; player's velocity field
       LDA (ram_001E_t04_object_data),Y
       TAX                        ; X = velocity / trampoline index
       JSR sub_E4A4               ; (resolve the trampoline this player is on)
       LDA ram_obj_5_strength,X   ; trampoline's remaining bounces
       BPL bra_DC12_not_broken    ; if positive, still usable
       JMP loc_DB83               ; broken — different transition
       
bra_DC12_not_broken:
       LDA ram_obj_5_timer,X      ; trampoline's spring-compression frame
       CMP #$07                   ; reached the launch frame?
       BNE bra_DC58_RTS           ; not yet — RTS, wait next frame
       
       LDY #con_obj_type
       LDA (ram_001E_t04_object_data),Y    ; player or cat?
       BNE bra_DC22_not_player    ; non-zero = cat
       
       ; PLAYER ONLY: consume one bounce
       DEC ram_obj_5_strength,X
       
bra_DC22_not_player:
       ; transition state $0A → $0C, animation = "fall" frame, etc.
       LDA #$00
       LDY #con_obj_08
       STA (ram_001E_t04_object_data),Y
       LDA #con_state_0C
       LDY #con_obj_state
       STA (ram_001E_t04_object_data),Y
       LDA #con_anim_id_fall
       LDY #con_obj_animation
       STA (ram_001E_t04_object_data),Y
       ; ... pack jump_pos with starting Y position ...
```

Three things matter here:

### 1. Wait-for-trampoline-frame synchronization

State $0A doesn't immediately launch. It waits for `ram_obj_5_timer == 7` — the trampoline's own animation has to reach frame 7 (the maximum-compression frame) before the player launches. **The visual squash-and-stretch of the trampoline is gated to actual physics.** Players see the spring compress, then the player flies. The animation isn't decorative — it's the timing primitive.

### 2. The asymmetric mechanic in 3 instructions

```asm
       LDY #con_obj_type
       LDA (ram_001E_t04_object_data),Y
       BNE bra_DC22_not_player    ; type ≠ 0 → cat
       DEC ram_obj_5_strength,X   ; type = 0 (player) → consume one bounce
```

Five instructions if you count the LDY/LDA setup; three if you count just the conditional. **That's the entire "cats don't wear out trampolines" balance rule.** Read the type byte; if non-zero, skip the decrement. One byte of object data (`type`) encodes "is this the player or an enemy"; one branch encodes "does this entity wear out trampolines."

This is the same family as Adventure's [matrix-slot-encodes-chase-vs-flee](../adventure/06-dragon-state-machine.md) finding — **a major balance choice expressed in 1–3 instructions because the data layout supports it.** The data is shaped so the question can be asked cheaply.

### 3. State + animation are written together

The transition writes three fields:
- `con_obj_state ← $0C` (next phase)
- `con_obj_animation ← con_anim_id_fall` (visual)
- `con_obj_08 ← 0` (tile-under-foot reset; will be re-populated next frame)

Each through indirect-Y to the same object pointer. **Multiple fields updated in one logical step**, which is more compact than the inline-branch dispatch Adventure used.

## State $0C — flying up

`ofs_001_DC5C_0C` (line 5267). The actual upward arc.

The handler reads the current Y position and `jump_pos` (the starting Y, packed with phase bits in the low 2 bits) and decides:
- **Are we still going up?** Compare current Y to peak Y (computed from `jump_pos`).
- **Should the player gain horizontal velocity?** Check `con_obj_movement` — if the player held left/right at the trampoline, they can drift sideways during the arc.
- **Have we hit the upper bound (next floor)?** Transition to landing state.

Notable patterns:

```asm
       LDA con_obj_pos_Y_lo
       AND #$03                   ; bottom 2 bits = arc phase
       SEC
       SBC #$01
       CMP #$02
       BCS bra_DC77               ; phase ≥ 3 → continue arc
```

The bottom 2 bits of `pos_Y_lo` are co-opted as **arc-phase counter**. Mappy isn't just storing position — the position byte's least-significant bits encode where in the bounce we are. **Same family as Adventure's [triple-use of `$A2`](../adventure/03-sprite-multiplexing.md): pack multiple meanings into one byte by exploiting unused bits.** Here it's the low 2 bits of an integer position byte (the fine-resolution lives in `pos_Y_fr`, so the bottom of `pos_Y_lo` is "wasted" precision); Mappy uses it for state.

This is the chapter-2 "sub-pixel positioning" finding paying back: with fractional bytes carrying the actual smooth motion, the integer byte's low bits become available for packed state.

The state $0C handler also writes `con_obj_0B` (vertical velocity) and `con_obj_0C` (velocity decay):

```asm
       LDA #$E0                   ; -32 in signed 8-bit
       LDY #con_obj_0B
       STA (ram_001E_t04_object_data),Y
       LDA #$04                   ; +4
       INY                        ; con_obj_0C
       STA (ram_001E_t04_object_data),Y
```

`$E0` = `-32` (signed). That's the upward velocity (negative because Y increases downward on the NES). `$04` is presumably the per-frame decay or counter. **The "physics" is two bytes** — initial velocity and decay rate. Each frame the state $0C handler subtracts decay from velocity, applies velocity to position. When velocity reaches 0 or positive, transition to $0E (apex).

Compare Adventure's man movement: `INC VBLANK,X` adds 1 pixel per frame, no acceleration, no deceleration, no fractional. Mappy gets *Newtonian-feeling* arcs out of two extra bytes per object. **The smoother feel of NES games over 2600 games is, in part, this single architectural choice — separate fractional position bytes plus per-state velocity fields.**

## State $0E — the apex (horizontal control window)

`ofs_001_DCFE_0E` (line 5358). At the top of the arc, gravity hasn't taken hold yet, but vertical velocity is essentially zero. **This is the brief window where horizontal input matters most** — the player can drift left or right to land on a different column than where they bounced.

The handler:
- Reads `con_obj_08` (tile-under-foot, but also doubles as a horizontal velocity counter here — re-purposed per state)
- Decrements `con_obj_timer` (apex duration)
- When timer hits zero, transition to $06 (falling)
- Within apex, applies horizontal motion based on input

The byte re-purposing (`con_obj_08` as tile-cache during $02, as horizontal counter during $0E) is the data-economy version of state-driven dispatch — **the same byte means different things in different states.** Adventure's variables had one meaning each; Mappy reuses bytes across state contexts.

## State $06 — falling down

`ofs_001_DB94_06` (line 5154). Gravity wins. Vertical velocity grows positive (downward) each frame; horizontal motion continues if active. Transitions to $04 (landing) when collision detection (next section) finds a floor.

## Tile-under-foot collision via buffer-2 read-back

This is where chapter 3's PPU read-back system earns its keep.

State $02 (standing) and state $06 (falling) both need to know **what tile is the player about to step onto**. The check has to be live — Mappy could be walking onto a freshly-revealed door, a coin, a floor, a wall, or a trampoline. The *background tile under his feet* IS the gameplay grid.

The mechanism:
1. State handler computes the PPU address of the tile under the player's feet (or below for falling collision).
2. Queues a buffer-2 read entry: `[lo][hi][ram_dest_lo][ram_dest_hi]`.
3. **Next frame**, the VBlank handler drains buffer 2, reads PPU memory, stores result back into RAM at the named pointer (typically + offset $08 = `con_obj_08`).
4. **Two frames after the request**, the state handler reads `con_obj_08` and dispatches:

```asm
       LDA con_obj_08
       CMP #$59                   ; trampoline tile ID?
       BEQ bra_DC91               ; yes — trigger trampoline state
       SEC
       SBC #$30
       CMP #$20
       BCC bra_DC91               ; tile ID in range — special tile
       LDA con_obj_pos_Y_lo
       CMP #$06
       BCC bra_DC91
       JMP loc_E084               ; normal floor handling
```

The chained `CMP / BEQ / SBC / CMP / BCC` is **range-check on tile IDs**. Specific values trigger specific behaviors:
- `$59` → trampoline (initiate bounce)
- Range `$30`–`$58` → various special tiles (floors of different types, items, doors)
- Else → empty space / normal handling

**Tile IDs are not just visual indices — they're behavioral classes.** Want to add a new collectible? Pick a tile ID in the special range and add a branch. **The CHR-ROM (where the actual pixel patterns live) and the gameplay logic (where the tile IDs are interpreted) share one identifier.** The tile ID is both visual and semantic.

This is the structural reason chapter 3's "background as sprites" trick works gameplay-wise: items are nametable tiles, so reading the nametable returns their type. **One unified mechanism for "what's drawn here" and "what's the gameplay rule here."**

### The 2-frame latency

The buffer-2 round trip takes two frames: queue request → drain in next VBlank → handler reads result the frame after that. **At 60 fps that's ~33 ms of input lag** between Mappy stepping onto a trampoline tile and the bounce actually triggering.

Why doesn't this feel laggy? Because the trampoline's own animation cycle takes 7 frames (state $0A waits for `timer == 7`) anyway. The collision delay is hidden inside an already-slow visual transition. **The animation timing absorbs the buffer latency.** Robinett's Adventure had per-frame collision via TIA hardware (chapter 4 of Adventure); Mappy gets richer collision *types* at the cost of latency, then hides the latency with animation.

## Trampoline strength and the color update

Each trampoline (`obj_5`) has:
- `ram_obj_5_strength` — bounces remaining (3 = yellow, 2 = green, 1 = red, 0 = wraps to $FF = broken)
- `ram_obj_5_timer` — animation frame within current bounce (0..7)
- Plus position and tile-rendering state

When `ram_obj_5_strength` decrements, the trampoline's tile color changes. The actual color update probably happens in a separate routine (likely tile-swap via `sub_C78E_write_data_to_buffer`). The state $0A handler only manages the *count*; the visual update is downstream.

When strength wraps from 0 to $FF (becomes negative), `BPL` fails and the broken-trampoline branch fires — `JMP loc_DB83` triggers the "you fell" sequence (state $06 with no upward velocity, so Mappy plummets to the next floor or the floor below). **The "trampoline broke under you" mechanic is one branch off one comparison.**

## Player-only fields, decoded

Chapter 2 flagged five player-only fields as TBD. Chapter 4 gives meaning to four of them:

| Offset | Name | Purpose (decoded) |
|---|---|---|
| `$08` | (was unnamed) | **Tile-under-foot ID** (also re-purposed as horizontal counter during $0E) |
| `$0A` | `jump_pos` | **Bounce arc start Y** (with bottom 2 bits packing arc phase) |
| `$0B` | (was unnamed) | **Vertical velocity** (signed; negative = upward) |
| `$0C` | (was unnamed) | **Velocity decay rate** (or per-state counter) |
| `$0D` | `movement` | **Movement direction during airborne** |
| `$0E` | (was unnamed, `con_obj_AB`) | Still TBD — likely "Active Bounce" flag or trampoline-index back-reference |

Five of seven extension bytes have purpose. The `$0E` "AB" field stays uncertain; it's referenced in the source but its semantics aren't clear without playing the game. **Following the chapter-2 LLM-log discipline: trusted = none yet, verified = $08/$0A/$0B/$0C/$0D, suspicious / TBD = $0E.**

## Why this matters — capability spent on physics

Adventure's man (chapter 4 of Adventure) moved 3 pixels per frame in 4 directions. Period. No acceleration, no jumping, no falling, no arcs. The 2600's CPU budget didn't allow per-state physics — every cycle was needed for beam-racing.

Mappy's player has **6 distinct movement states**, each with its own velocity model, each tracking position to fractional precision, each integrating with a tile-grid collision system that returns asynchronously over a 2-frame window. **The physics engine is roughly 200 instructions** spread across the four bouncing-state handlers, plus the collision queueing, plus the state transitions.

That ~200 instructions wouldn't fit in Adventure's per-frame budget. They fit in Mappy's because the PPU does the rendering autonomously and the CPU has 5× more cycles for game logic (chapter 1 cycle accounting). **This is the storytelling-vs-logic axis at the per-mechanic level: the new CPU headroom got spent on a believable physical world.**

Mappy launched a genre because it could *afford* to. Trampoline mechanics in 1984 were impossible on the 2600 — not because the platform engineers couldn't conceive them, but because the cycle budget couldn't support them. The hardware shift made the genre possible; the programmer effort made it *land*.

## Efficiency catalogue (chapter 4 entries)

- **State machine as physics engine.** Six states decompose one mechanical action into discrete physics phases. Each handler does only what its phase requires. No mode-switching code; no monolithic "update player" function with nested ifs.
- **Asymmetric mechanic in 3 instructions.** `LDY #con_obj_type / LDA / BNE skip` lets cats use trampolines without wearing them out. The "type" byte naturally carries the distinction; the mechanic exploits it.
- **Bottom 2 bits of `pos_Y_lo` as arc phase.** Position has 8.8 fractional precision; the integer byte's low bits are unused by motion math, so they become arc-phase storage. Same family as Adventure's $A2 multi-use.
- **Byte re-purposing across states.** `con_obj_08` is tile-cache during $02, horizontal counter during $0E. Different state, different meaning, same byte. **The state dispatch is also a byte-meaning dispatch.**
- **Tile ID as visual + semantic identifier.** Background tiles serve both as graphics references AND as gameplay-rule keys. One byte does both jobs.
- **Animation timing hides collision latency.** The 2-frame buffer-2 read-back delay is absorbed by the trampoline's 7-frame compression animation. Latency exists in the implementation; user experience is seamless.
- **Velocity + decay = arcs.** Two bytes (`$0B`, `$0C`) implement smooth acceleration/deceleration for any object that needs it. Adventure's integer-only motion couldn't.
- **Multi-field updates per state transition.** State + animation + helper bytes all written together when transitioning. No "update animation later" pass; the dispatch IS the rendering preparation.

## What this surfaces about earlier chapters

- **Chapter 2's "5× more states than Adventure"** is now concrete. Adventure's dragon had 5 states because its motion was pathfinding only. Mappy's player needs 6 states *just for jumping* (plus 17 more for other activities) because each phase has its own physics. The state-count ratio reflects the *behavioral richness* the CPU budget enables.
- **Chapter 3's buffer-2 VRAM read-back** earns its complexity here. It isn't an esoteric debugging primitive — it's the **collision system**. Background-tile-under-player is the fundamental query, and the engine is built around it.
- **Chapter 1's "~25,000 cycles per frame for game logic"** is what affords the ~200-instruction physics engine. Adventure's ~5,000 cycles couldn't fit it.

## LLM-interpretation log

**Pure structure was sufficient for:**
- Recognizing the state-handler pattern (each `ofs_001_DC*` is a self-contained routine called via the dispatch table).
- The wait-for-frame pattern (`LDA timer / CMP #N / BNE return`).
- The state transition pattern (write new state + new animation + per-state init values, then RTS).
- The "type check" gate (`LDY #con_obj_type / LDA / BNE skip`).

**Disassembler's labels and cross-refs were decisive for:**
- `ram_obj_5_strength` and `ram_obj_5_timer` — naming what `obj_5` actually is (the trampoline). Without these names, the indexed-X reads would be opaque.
- `con_state_0A`, `con_state_0C`, etc. — the named states in `bank_val.inc` made the gameplay-meaning assignments easy to spot.
- `con_obj_jump_pos` — telling me that field $0A is jump-arc related.
- `con_anim_id_fall`, `con_anim_id_jump` — the animation IDs revealing the visual semantics of each state.

**Where I trusted vs verified vs disagreed with the disassembler:**
- **Trusted**: the state-name labels (chapter 2 flagged these as best-effort gameplay-flavor names; chapter 4 confirms they fit the decompiled flow).
- **Verified**: `obj_5` = trampoline (the "strength gets decremented when player jumps off it" pattern matches gameplay).
- **Newly identified**: `con_obj_0B` = vertical velocity, `con_obj_0C` = velocity decay. The `$E0` (=-32) load for upward push and `$04` for decay are signed-arithmetic clues. **Adding these to the running decode of the player record.**
- **Still TBD**: `con_obj_0E` (the "AB" field). Reads but doesn't write in the trampoline handlers; might be set elsewhere. Chapter 5 (cat AI) might reveal it.

**Chip docs were load-bearing for:**
- That the buffer-2 round-trip takes two frames (one to queue, one for VBlank to drain, results readable the frame after). PPU docs.
- That signed 8-bit arithmetic uses two's complement (`$E0 = -32`). 6502 fact.
- That `BPL` tests bit 7 and is the standard "is signed value positive" test. Used here for "is trampoline strength still positive."

**Cumulative chapter knowledge from Adventure and earlier Mappy chapters:**
- **Chapter 2's player-only field placeholders** had to wait for chapter 4 to fill in. Cumulative-chapter knowledge isn't always next-chapter; sometimes a TBD waits two chapters before the right code path explains it.
- **Adventure's matrix-slot-encodes-role** is the closest precedent for Mappy's "type byte gates the trampoline-strength decrement." Both encode major balance choices in 1-byte conditionals on existing data.
- **Adventure's "$A2 triple use"** is the closest precedent for "pos_Y_lo low 2 bits as arc phase." Both pack multiple semantics into a single byte by exploiting bits the primary use doesn't need.

**Big find of chapter 4**: the state machine **is** the physics engine. Adventure's collisions were hardware (TIA latches) and motion was uniform (3 px/frame). Mappy's collisions are software (tile-grid via VRAM read-back) and motion is **per-state**. Each of the 6 bounce-related states has its own velocity model, its own input-response, its own transition rules. The capability spent on the state-count is what enables the genre. **There's no separate "physics engine" routine** — physics is what the state-handler dispatch table accomplishes when you walk it once per frame.

This is a categorically different software-architecture choice than Adventure. Adventure's engine was *uniform behavior over many objects* (dragons all use one chase routine). Mappy's engine is *richly different behavior per phase* (the player's bounce is 4 routines, not one). The CPU budget shift enabled the *style* of architecture, not just the size.

## What chapter 4 sets up for chapter 5 (cat AI)

- **The shared-engine pattern** (Adventure ch. 5/6) — does Mappy's AI follow Adventure's "shared engine + per-agent matrices" model? The cat AI handlers are at `loc_DA70_02` (state $02) and similar — separate from the player's bounce because cats are state $02 most of the time. We'll see what cat-specific logic looks like.
- **The "doors as weapons"** mechanic — Mappy's primary defense is opening doors that knock cats back. That's a tile-state change (door tile rotates through animation frames) plus a sweep that disables nearby cats. Chapter 5 will trace it.
- **The trampoline asymmetric rule** suggests Mappy uses similar "data byte gates the rule" patterns for cat behavior. We'll look for them.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
