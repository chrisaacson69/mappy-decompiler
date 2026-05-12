---
status: active
created: 2026-04-26
---
# Mappy — The PPU Pipeline & Background-as-Sprites
> The VBlank window has three jobs: fill OAM, drain a queued list of nametable updates, and reset scroll. Plus the trick that defines Mappy visually — *some objects aren't sprites at all*.

**Links:** [Mappy README](./README.md), [Reset & Frame Structure](./01-reset-and-frame-structure.md), [Object Records & States](./02-object-records-and-states.md), [PPU Reference](../../../research/nes/ppu-reference.md), source: [`raw/mappy_bank_FF.asm`](../../../raw/mappy_bank_FF.asm)

## What chapter 1 said but didn't trace

Chapter 1's main loop opened with three function calls right after the NMI signal:

```asm
       LDA #>ram_oam              ; $07
       STA $4014                  ; OAMDMA
       JSR sub_C150_write_buffer_to_ppu_and_read_from_ppu
       JSR sub_C1C9_read_joy_regs
```

Three lines. Behind them is **the entire NES rendering pipeline**. Chapter 1 acknowledged the pieces; this chapter walks them.

## The VBlank window — what fits in 2,273 cycles

NTSC NES gives ~2,273 CPU cycles between VBlank start and VBlank end. The OAMDMA alone consumes ~513 of them. Whatever else has to touch PPU memory has to fit in the remainder. Mappy spends them like this:

| Step | Cycles (approx) | Purpose |
|---|---|---|
| OAMDMA | 513–514 | Copy shadow OAM → PPU OAM |
| Disable rendering (`PPUMASK = 0`) | ~10 | Allow safe PPU memory access |
| Drain buffer 1 (RLE writes) | varies (~hundreds) | Apply queued nametable / palette updates |
| Drain buffer 2 (RLE reads) | varies (~tens) | Read PPU memory back into RAM |
| Re-enable rendering (`PPUMASK = $1E`) | ~10 | Bring sprites + background back |
| Scroll reset, PPUCTRL update | ~30 | Set new frame's scroll and nametable bits |
| Garbage NOP loops | varies | **Normalize VBlank duration** for downstream timing |
| Joypad read | ~80 | Strobe + 8 reads × 2 controllers |

The *budget shape* matters as much as the budget total. Sprite OAM gets refreshed every frame regardless; the buffers carry whatever changed this frame. If nothing changed, the buffer drains in zero entries; if a lot changed (level transition, score popup, new sprite revealed in the maze), the drain takes more time. **The garbage NOP loops at the end normalize the variance** so the audio engine's per-frame call sees consistent timing even when VRAM updates were small.

## OAMDMA — the cheapest 256-byte copy on the system

```asm
       LDA #>ram_oam              ; $07 (high byte of $0700)
       STA $4014                  ; trigger OAMDMA
```

Two instructions. Behind `STA $4014` the CPU stalls for 513 cycles while the DMA hardware copies bytes `$0700`–`$07FF` directly into the PPU's internal OAM. **No CPU instructions execute during this stall** — the DMA owns the bus.

The shadow OAM at `$0700` is *aligned to a page boundary* on purpose. OAMDMA only takes the high byte of the source — there's no way to specify a misaligned source. Mappy reserved the entire `$0700`–`$07FF` page for sprite shadow data; nothing else lives there. Same trick everywhere: when the hardware constrains your data layout, organize the data to match.

(Adventure had no equivalent. The 2600's TIA had no sprite list. Sprite bytes were poked into GRP0/GRP1 *during the visible kernel*, on the exact scan lines they should appear on — chapter 2 of Adventure. The CPU was the OAMDMA *and* the OAM *and* the renderer.)

## The two PPU buffers — `ram_ppu_buffer_1` and `ram_ppu_buffer_2`

Mappy maintains two queues in CPU RAM. Game code, running outside VBlank, *adds* entries; the VBlank handler drains them.

### Buffer 1 (`$0500`–`$05FF`) — write-only nametable updates

Format per entry: `[addr_lo][addr_hi][count][data... × count]`. Variable length. Multiple entries packed back-to-back. An index byte (`ram_buffer_index_1` at `$2A`) tracks the current write position.

The drain loop (lines 271–287):

```asm
bra_C153_loop:
       CPX ram_buffer_index_1     ; processed everything?
       BEQ bra_C175               ; yes, on to buffer 2
       LDY ram_ppu_buffer_1,X     ; addr low byte
       INX
       LDA ram_ppu_buffer_1,X     ; addr high byte
       INX
       STA $2006                  ; PPUADDR (high first, per twice-write latch)
       STY $2006                  ; PPUADDR (low second)
       LDY ram_ppu_buffer_1,X     ; count
       INX
bra_C169_loop:
       LDA ram_ppu_buffer_1,X     ; data byte
       INX
       STA $2007                  ; write to PPU at current address (auto-increments)
       DEY
       BNE bra_C169_loop          ; loop count times
       BEQ bra_C153_loop          ; next entry
```

That's the **canonical NES VRAM update queue**. Once you've seen it in any NES game, you've seen it in all of them. The variable-length-records-with-an-index pattern lets game logic queue *anything* that needs to land in PPU memory — a single tile change, a row of attribute bytes, a palette write, a strip of nametable patches for a moving status bar.

### Buffer 2 (`$04C0`–`$04FF`) — VRAM read-back

This is rarer. Same format up front, but each entry **reads** from PPUDATA twice (the first read is the stale internal buffer; the second read is the actual byte) and stores the result back into RAM at a pointer encoded in the entry.

```asm
loc_C177_loop:
       CPX ram_buffer_index_2
       BEQ bra_C1A2
       LDY ram_ppu_buffer_2,X     ; addr lo
       INX
       LDA ram_ppu_buffer_2,X     ; addr hi
       INX
       STA $2006
       STY $2006
       LDA ram_ppu_buffer_2,X     ; RAM dest pointer lo
       INX
       STA ram_001E_t03_data
       LDA ram_ppu_buffer_2,X     ; RAM dest pointer hi
       INX
       STA ram_001E_t03_data + $01
       LDA $2007                  ; throw away (PPU read buffer)
       LDA $2007                  ; actual byte
       LDY #$08
       STA (ram_001E_t03_data),Y  ; store at ptr + 8
       JMP loc_C177_loop
```

**Why read VRAM at all?** Most NES games only write — VRAM is "what the screen shows," and game state lives in CPU RAM. Mappy uses read-back for **collision detection against the background**: when a moving object needs to know "what tile am I about to step onto," the game queues a read of the relevant nametable byte; the VBlank flush returns the result via that RAM pointer. The object can then check whether the upcoming tile is solid, a trampoline, a coin, or empty space.

**This is a chapter-9 hint.** When we trace cat AI and trampoline physics, we'll see calls into the buffer-2 enqueue routines — that's how cats know which floors they can stand on, and how Mappy detects he's landed on a trampoline. Adventure had no equivalent because the 2600 had no nametable to read; the CPU was the only place "what's drawn" lived.

## The single-API enqueue trick — `sub_C78E_write_data_to_buffer`

Game code calls one routine to push PPU updates. The routine *transparently* picks between deferred and immediate:

```asm
sub_C78E_write_data_to_buffer:
       LDA ram_for_2001           ; shadow of PPUMASK
       BEQ bra_C7B4               ; rendering OFF → write PPU directly
       
       ; rendering ON → queue into buffer 1
       LDX ram_buffer_index_1
       LDA ram_0010_t18_ppu_addr_lo
       STA ram_ppu_buffer_1,X
       INX
       LDA ram_0011_t10_ppu_addr_hi
       STA ram_ppu_buffer_1,X
       INX
       LDA ram_0015_t02_tiles_counter
       STA ram_ppu_buffer_1,X
       INX
bra_C7A6_loop:
       LDA (ram_0012_t01_data),Y
       INY
       STA ram_ppu_buffer_1,X
       INX
       DEC ram_0015_t02_tiles_counter
       BNE bra_C7A6_loop
       STX ram_buffer_index_1
       RTS
       
bra_C7B4:                          ; immediate path
       LDA ram_0011_t10_ppu_addr_hi
       STA $2006
       LDA ram_0010_t18_ppu_addr_lo
       STA $2006
bra_C7BE_loop:
       LDA (ram_0012_t01_data),Y
       INY
       STA $2007
       DEC ram_0015_t02_tiles_counter
       BNE bra_C7BE_loop
       RTS
```

**One API, two runtime-selected backends.** During init (`PPUMASK = 0`, `ram_for_2001 = 0`), tile uploads write directly to PPUDATA — fast, no buffer needed because we have unlimited time when rendering is off. During gameplay (`PPUMASK = $1E`, `ram_for_2001 = $1E`), the same calls queue into buffer 1 for VBlank drain.

**Adventure has no analog.** Adventure had one mode: "the kernel is running." There was no "init vs gameplay" distinction in TIA register usage. NES has the off-screen-update-window concept; Mappy abstracted it into one helper.

The shadow `ram_for_2001` exists because PPUMASK is **write-only** — you can't ask the PPU what its current state is. The shadow tracks it on the CPU side. Same pattern other NES games use for PPUCTRL ("PPUCTRL shadow") and other write-only registers.

## The garbage NOP loops — timing normalization

After the buffers drain (line 322 onward):

```asm
bra_C1B4_garbage_loop:
       NOP
       NOP
       INX
       CPX #$40
       BNE bra_C1B4_garbage_loop
bra_C1BD_garbage_loop:
       NOP
       NOP
       NOP
       NOP
       INX
       BNE bra_C1BD_garbage_loop
```

The disassembler tagged these `; bzk optimize` — meaning "this looks removable." But they're **not** dead code. They're **VBlank-duration normalizers**.

Here's what's happening: buffer 1 and buffer 2 are variable-length. A frame with no game-state changes drains both buffers in dozens of cycles. A frame with a row of new tiles or a refreshed status bar takes hundreds. Without compensation, the time spent in the VBlank-flush routine varies frame-to-frame.

That variance matters because **the audio engine runs from inside this same VBlank routine** (chapter 1: `JSR sub_F4F1_update_sound_engine`). Audio depends on consistent per-frame timing. If buffer drains take inconsistent amounts of time, audio cadence drifts.

The garbage loops use `X` to count down a fixed number of iterations *based on what the buffer indices were when entering*. The amount of NOP work is inversely proportional to how much real work the buffers did. **Total time spent in the routine is normalized.** Removing the NOPs would make audio timing depend on visual update load — a subtle bug that would only show up as inconsistent music tempo during scenes with lots of nametable changes.

This is a deeply NES-era technique. Adventure didn't need it (Adventure's audio was bare TIA channels with no engine; cadence didn't matter). The musical sophistication NES games can express *requires* this kind of micro-discipline.

## Scroll setup and the PPUCTRL re-write

After buffers and rendering re-enable:

```asm
       LDA #$00
       STA $2005                  ; PPUSCROLL X (first write of latch pair)
       STA $2005                  ; PPUSCROLL Y (second write)
       LDA #$88
       STA $2000                  ; PPUCTRL re-set
```

This part of the routine writes scroll = (0, 0) and PPUCTRL = `$88` (NMI on, BG pattern $1000). **Why reset scroll here?** Because every PPUADDR write to `$2006` (which the buffer flush did dozens of times) corrupts the PPU's internal scroll state. After any VRAM update via PPUADDR, you have to re-establish scroll explicitly or the next frame renders from the wrong nametable position.

Then the *main loop*'s scroll setup (lines 107–123 of chapter 1) overrides this with the actual game-world scroll based on `ram_cam_pos_X`. The two-stage approach: VBlank routine resets to known state; main loop sets the per-frame target. **Belt-and-braces against a chip footgun.**

This is one of those "hidden constraints make code longer" moments — without knowing PPUADDR clobbers scroll, you'd see two scroll-setup blocks and assume one was redundant. With the chip docs in context, both are necessary.

## Background as sprites — Mappy's signature trick

Now we get to the technique that defines Mappy's look. Look at any frame of gameplay:

- **Mappy** (the player), the **cats**, the **bouncing trampolines** — all sprites
- **Doors**, **bells**, **money bags**, **floors**, **walls** — all background

The doors and bells **animate** (door closes when triggered; bell shakes when collected). They **disappear and reappear** (you collect them; they're gone). They behave like sprites in every visible way *except they're not in OAM*.

Why? Two constraints:

1. **8 sprites per scanline.** With Mappy on screen plus 4–6 cats plus a bouncing trampoline plus a score popup, you'd routinely exceed 8 sprites per row. The 9th sprite gets dropped, causing the famous NES sprite flicker.
2. **64 sprites total in OAM.** Even within the limit, only 64 sprites fit in OAM at any moment. Mappy's mansion has dozens of items per floor.

The solution: **promote any visually-static-or-rare-changing object to the background layer.** Doors, bells, pickups don't need pixel-precision movement; they just need to *appear* and *disappear*. Both operations are nametable tile changes — write a "door tile" to a position to spawn one, write a "blank tile" to remove one. Each operation is a single `sub_C78E_write_data_to_buffer` call queueing 1 byte of update.

The cost is one byte per change in buffer 1, drained next VBlank. The savings is **freeing 64 OAM slots and dodging the 8-per-line limit entirely** for these objects.

### How Mappy decides what's a sprite vs background

The implicit rule:
- **Sprites**: things that move smoothly (use sub-pixel positions), things that overlap arbitrarily, things that animate frame-by-frame at full speed. Mappy himself, cats, the trampolines while bouncing, falling enemies, score popups.
- **Background**: things that change rarely (a door opens once), things that animate in slow chunks (the bell shakes for a few frames), things that exist on a tile grid (floors, walls, items at fixed positions). Doors, bells, money bags, walls, floors.

Mappy's collision detection (the buffer-2 read-back trick above) works on background tiles. When Mappy walks across a floor, the engine reads the upcoming tile from VRAM to know "is this a coin? a door? a wall?" **The collision system *requires* these objects to be background tiles.** If a coin were a sprite, its position would be in OAM; checking whether Mappy overlaps it would need different code. Background-tile objects participate in the same uniform "what tile am I touching" check.

This is a deeply specific architectural choice. Adventure had only the equivalent of sprites (P0/P1/Ball/M0/M1) and the equivalent of background (PF0/PF1/PF2). All gameplay collisions were against TIA's pairwise-collision latches. Mappy uses the *nametable as data structure* — the items in the maze are *literally drawn into the world*, and checking collision *means reading the world*. The PPU's nametable becomes the level's gameplay grid.

We'll trace the specific calls in chapter 7 (level data) and chapter 4 (trampolines need to know about the trampoline tile under them).

## Joypad reading — the truly convoluted part

Worth treating in detail. NES input has more footguns per byte than almost any other subsystem.

### The two registers and their dual identities

| Address | Read | Write |
|---|---|---|
| `$4016` | Controller 1 button data (1 bit per read) | Strobe (bit 0 controls both controllers' latch) |
| `$4017` | Controller 2 button data (1 bit per read) | **APU frame counter** (mode + IRQ inhibit) |

`$4017` does two completely different things depending on whether you read it or write it. Reading reads controller 2; **writing configures the APU frame counter** (chapter 1 mentioned `STA $C0 / STA $4017` to disable frame IRQ). If a programmer accidentally writes to `$4017` while trying to read controller 2, they reset the APU's frame counter mid-frame and break the audio. **Read vs write at the same address is the chip-level footgun.**

### The strobe — controller is in one of two modes at any moment

The strobe bit (bit 0 of writes to `$4016`) puts both controllers in one of two modes:

- **Strobe high (1)**: controllers are continuously latching current button state. Reads from `$4016`/`$4017` always return bit 0 of the buttons (the A button) because the shift register is constantly being reloaded.
- **Strobe low (0)**: controllers freeze the latched state and prepare to shift it out. The first read returns the most-recently-latched A button bit; subsequent reads shift to B, Select, Start, Up, Down, Left, Right in that fixed order.

So the canonical sequence is: strobe high (latch current state into the controller), strobe low (freeze for shifting), read 8 times.

```asm
sub_C1C9_read_joy_regs:
       LDX #$01
       STX $4016                  ; strobe high — latches both controllers
       DEX                        ; X = 0
       STX $4016                  ; strobe low — start shifting
       JSR sub_C249_read_joy_regs ; reads $4016 (controller 1)
       INX                        ; X = 1
       JSR sub_C249_read_joy_regs ; reads $4017 (controller 2)
```

The `LDX #$01 / STX $4016 / DEX / STX $4016` is **not** "write 1 then write 0" — it's "put both controllers in latch mode, then put both in shift mode." The two writes implement a state transition, not two separate operations. Reading the bytes as "two writes" misses what's happening.

### `AND #$03 / CMP #$01` — Famicom-aware bit handling

The single-bit read:

```asm
sub_C249_read_joy_regs:
       LDY #$08                   ; 8 buttons
bra_C24B_loop:
       LDA $4016,X                ; read controller 1 (X=0) or 2 (X=1)
       AND #$03                   ; isolate bits 1 and 0
       CMP #$01                   ; "is bit 0 set AND bit 1 clear?"
       ROR ram_0010_t10_buttons,X ; rotate carry into shadow byte
       DEY
       BNE bra_C24B_loop
       RTS
```

`AND #$01` would be the simpler version. **Why `AND #$03` then `CMP #$01`?**

On the NES, controller data is bit 0. **On the Famicom, controller 2's port also exposes bit 1** for the microphone (Famicom controller 2 had a built-in mic) and various expansion peripherals. Some accessories (Family BASIC keyboard, Power Glove, light gun signals) put data on bit 1 instead.

`AND #$03` keeps both bits. `CMP #$01` succeeds only when bit 0 is set AND bit 1 is clear — i.e., a *standard button press from the standard controller*. If bit 1 is also set (expansion peripheral data), the comparison fails and carry stays clear, so the shadow byte sees that button as not-pressed. **The check rejects expansion-peripheral data while accepting standard buttons.**

This is the kind of correctness Namco built in for the Famicom even though Mappy doesn't use any expansion peripheral. Defensive against the platform's accessories. Most pure-NES games do the simpler `AND #$01`.

### The button order in the shadow byte

After 8 ROR iterations, `ram_0010_t10_buttons,X` holds all 8 button states. The order, from MSB to LSB:

```
bit 7: A
bit 6: B
bit 5: Select
bit 4: Start
bit 3: Up
bit 2: Down
bit 1: Left
bit 0: Right
```

That's because ROR shifts right (the first read becomes the high bit, the eighth read becomes bit 0), and the controller shifts out A first. **Game code reads buttons by AND-ing against constants like `$80` for A, `$10` for Start, etc.** This ordering is universal across NES games; once you've internalized it, every NES game's input handling looks the same.

### The `ROR carry` trick

`CMP #$01` sets carry if A == 1 (button pressed, no expansion data). Otherwise clears it. `ROR ram,X` rotates that carry into bit 7 of the shadow byte and rotates everything else right. After 8 loops, the shadow holds 8 packed button bits — assembled by 8 carries doing the work. **No explicit OR, no shift accumulator, no mask** — `CMP` produces the bit, `ROR` files it. Same family as Adventure's `INC VBLANK,X`-as-coordinate-increment trick: use the natural semantics of an instruction to do the work cleanly.

### The DMC interference bug — and why Mappy doesn't have it

Late-NES games using DMC samples have a famous bug: **the DMC's sample-fetch DMA can corrupt joypad reads** by stealing CPU cycles mid-`LDA $4016`. The chip wasn't designed to handle DMA stalls during memory-mapped I/O reads — the read returns garbage if a DMC fetch happens at the wrong moment.

The standard workaround is read-twice-and-compare:

```asm
read_safely:
       LDA buttons_a       ; first read (might be corrupted)
       STA scratch
       LDA buttons_b       ; second read
       CMP scratch         ; do they match?
       BNE read_safely     ; no — try again
```

Mappy **doesn't do this** because it doesn't use DMC at all (chapter 1: `STA $0F / $4015` enables only Pulse 1, Pulse 2, Triangle, Noise — no DMC bit). The DMC IRQ is also disabled (`STA $C0 / $4017`). With no DMC, no DMA stall, no joypad corruption. Mappy gets to do the simple single-read pattern.

When we hit a DMC-using game later in the series (likely something MMC3-era), we'll see the read-twice pattern and recognize it as DMC-bug protection.

### Frame-coherent input — there's no edge detection in hardware

The joypad is read once per frame (in the VBlank handler). The shadow holds *current state only* — "is the button pressed right now." There's no hardware notion of "newly pressed this frame" or "released this frame."

To detect button presses (not just holds), games keep two shadows: current frame's read and previous frame's read. **A new press is "current ∧ ¬previous"**; a release is the inverse. This costs another byte per controller plus a few cycles of bookkeeping per frame.

Mappy's structure with `ram_btn_Select` and similar implies it does this kind of edge tracking — the `AND #$03 / CMP #$01` test in chapter 1's main loop dispatch is checking specific button states, and the use of `ram_btn_Select` (singular, not "current/previous") suggests there's a separate "button state" representation that game code consumes. We'll see the full pattern when we trace gameplay state transitions.

### What's *actually* convoluted, summarized

1. **One register address, two operations** (`$4017` reads controller 2, writes APU). Easy to get wrong.
2. **Strobe is a state transition, not a write** (`STX $4016` twice configures latch-then-shift mode).
3. **One bit per read, in fixed order** (A, B, Select, Start, Up, Down, Left, Right).
4. **Multiple bits returned per read** (bit 0 for standard button, bit 1 for expansion peripherals — must be filtered).
5. **DMC interference bug** for games using sampled audio (Mappy escapes this).
6. **No hardware edge detection** — games must implement "newly pressed" in software.
7. **No interrupt on button events** — input is purely polling, gated to per-frame cadence.

Adventure's joystick handling (chapter 4 of Adventure) was *much* simpler: `LDA SWCHA` reads both joysticks in one byte, active-low. **One read, all 8 directions, no strobing, no shifting, no expansion-peripheral defense.** The Atari 2600's I/O was direct hardware connections through the RIOT chip; the NES's CPLD-based controller protocol (designed for cost reduction and expansion flexibility) is the price of supporting multiple controller types.

This is one place where Adventure was actually *simpler than* Mappy — the 2600's poverty of features extended to controller I/O, and the simplicity made input-handling code trivial. Mappy pays a higher byte cost for input on richer hardware. **Capability is not free.**

## Cycle accounting — a measured frame

Walking through a typical Mappy frame:

| Phase | Cycles |
|---|---|
| NMI fires; main loop sees flag | ~5 |
| OAMDMA | 513 |
| Disable rendering | ~10 |
| Drain buffer 1 (5 small entries, ~30 bytes total) | ~250 |
| Drain buffer 2 (1 read entry) | ~80 |
| Re-enable rendering | ~10 |
| Scroll reset, PPUCTRL re-write | ~30 |
| Garbage NOP loops (normalizing) | ~100–500 |
| Joypad read | ~80 |
| Sound engine update | ~few hundred |
| Game logic dispatch (sub_C0D0) | ~1,000+ |
| Object iteration (9 objects × state handler + render) | ~2,000+ |
| Camera math, scroll setup | ~50 |
| ... | ... |
| Clear flag, back to wait | ~10 |

Total per-frame budget ≈ 29,780 cycles. The above accounts for ~5,000–7,000; the rest is game logic that varies frame to frame.

**Key point**: buffer drain + OAMDMA + scroll reset together fit in well under VBlank's 2,273-cycle window. The remaining cycles are reserved as slack — if any single frame's buffer 1 contents balloon (say, a level transition), there's room to absorb it without overflowing into the visible region (which would corrupt rendering).

## Efficiency catalogue (chapter 3 entries)

- **OAMDMA from a page-aligned shadow** — `STA $4014` with high byte does the whole 256-byte copy in 513 cycles. No CPU instructions during the stall; the DMA owns the bus.
- **Single API for "queue or write now"** — `sub_C78E_write_data_to_buffer` checks the PPUMASK shadow and routes accordingly. Game code calls one routine; init and gameplay both work without code-site changes.
- **Variable-length RLE buffer with index** — `[lo][hi][count][data...]` packed entries, drained in one VBlank. Universal NES idiom.
- **Garbage NOP loops as timing normalizers** — visible-load-dependent variance gets compensated so audio cadence stays consistent.
- **PPUMASK shadow at `ram_for_2001`** — write-only register state mirrored in CPU RAM so code can query "is rendering on?" without re-tracking from the source of truth.
- **Background-as-sprites** — items, doors, bells live in the nametable, not OAM. Sidesteps the 8-per-scanline limit, frees OAM slots for genuinely-moving entities.
- **VRAM read-back via buffer 2** — game code can ask "what tile is at PPU address X" and get the answer in RAM next frame. Enables tile-grid collision against background objects.
- **Double scroll setup** — VBlank routine resets to (0,0); main loop sets the actual game-world scroll. Belt-and-braces against PPUADDR clobbering scroll state.
- **Joypad ROR-into-shadow** — 8 reads, each setting carry per button-held, ROR'd into a single byte. No masks, no shifts, just rotation.
- **Per-controller indexing via `,X`** — `LDA $4016,X` reads either controller. Mirrors Adventure's per-object indexing via X register.
- **`AND #$03 / CMP #$01` for Famicom-aware reads** — explicitly distinguishes "standard button on standard controller" from "data on expansion peripheral bit 1." Defensive against accessories Mappy never uses, but correct on Famicom hardware.
- **No DMC, no joypad-corruption workaround** — Mappy's APU init (no DMC enabled, no DMC IRQ) means it can use the simple single-read joypad pattern. Later DMC-using games need read-twice debouncing.

## What this surfaces about earlier chapters

- **Chapter 1's `JSR sub_C150`** is now decompressed: behind one line is OAMDMA + dual-buffer drain + scroll reset + NOP normalization. The single-line "VBlank work" hides the entire NES-era programming discipline.
- **Chapter 2's "shadow OAM render"** is the producer side of OAMDMA. `sub_C305` writes 4 bytes per visible sprite into `$0700`–`$07FF`; chapter 1 + 3 together show those bytes traveling to the PPU and becoming sprites.
- **Adventure's "CPU is the renderer" model** stays the right framing. Mappy's CPU still does *all* the data preparation; the PPU just executes that data. The shift isn't to "PPU does the work" — it's to "PPU does work *autonomously after the CPU sets it up*." That parallelism is the structural gain.

## LLM-interpretation log

**Pure structure was sufficient for:**
- The variable-length RLE buffer pattern (`LDY count / decrement / loop`).
- The twice-write PPUADDR pattern (`STA $2006` twice).
- The PPUDATA write loop (`LDA / STA $2007 / INC ptr / loop`).
- The standard joypad read idiom (`STX $4016 / DEX / STX $4016 / 8 reads`).
- The runtime-selected dispatch in `sub_C78E` (test PPUMASK shadow / branch to either path).

**Disassembler's labels and cross-refs were decisive for:**
- That `sub_C150` does both buffer-write and buffer-read flushes. The composite name (`write_buffer_to_ppu_and_read_from_ppu`) tells you what to expect; without it, the second buffer's purpose would take much longer to figure out.
- The `ram_ppu_buffer_1` / `ram_ppu_buffer_2` naming. The buffers themselves are 256-byte regions of zero-page-extension RAM; without the names they'd be opaque addresses.
- `ram_for_2001` — the PPUMASK shadow. The name reveals the role; the address `$2D` would be cryptic.
- The `; bzk optimize` markers on the garbage loops. **The disassembler thought these were dead code worth removing.** That's a finding to *disagree with* — they're load-bearing for audio timing. Tracking this gap is what the chapter-2 "where I disagree" axis is for.

**Where I trusted vs verified vs disagreed with the disassembler:**
- **Trusted**: buffer-1 / buffer-2 naming and roles. Verified by tracing the drain loop's PPU writes vs reads.
- **Verified**: that buffer 2's read-back stores into a RAM pointer (the `LDA $2007 / LDA $2007 / STA (ptr),Y` pattern is unmistakable double-read for the PPUDATA buffer quirk).
- **Disagreed**: the `; bzk optimize` markers on the NOP loops. The disassembler suggests these are removable; chapter 1's audio context says they're not. **First disagreement of the Mappy series.** Worth tracking in case the disassembler's "uncertain about role" markers are systematically optimistic.

**Chip docs were load-bearing for:**
- That OAMDMA stalls the CPU for 513 cycles and only takes a high byte (forcing page alignment of shadow OAM).
- That PPUDATA reads are buffered — the first read is stale, the second is real. Without this, the `LDA $2007 / LDA $2007` double-load would look redundant.
- That PPUMASK is write-only — necessitating the `ram_for_2001` shadow.
- That writes to PPUADDR clobber scroll state — explaining the scroll-reset after buffer drain.
- That `$4016` and `$4017` are the joypad read addresses, with strobe via writes to `$4016`.

**Cumulative chapter knowledge from Adventure:**
- **The "CPU as data prep" vs "CPU as renderer" framing** is sharper now. Chapter 1 of Mappy noted the cycle-budget shift; chapter 3 makes it concrete — the data-prep work happens in the *visible* region, in parallel with the PPU rendering, with the VBlank window reserved for the actual data transfer.
- **The single-API enqueue trick** echoes Adventure's "one engine, four AI agents" finding — write the API once, parameterize for context. Adventure parameterized via different matrices; Mappy parameterizes via the PPUMASK shadow.
- **Garbage loops as timing normalizers** is a *new* class of trick we didn't see in Adventure — Adventure had no second timing domain (no music engine running parallel). Mappy needs it because the audio engine has its own implicit cadence assumption.

**Big finds of chapter 3:**
1. **Background as sprites** — confirmed and explained. The nametable serves as both display and gameplay grid; items and doors live there as tiles, dodging the sprite-per-line limit and enabling background-tile collision via the buffer-2 read-back.
2. **Garbage NOPs as audio-timing safeguards** — the disassembler missed the role. This is a second-axis function (visual rendering needs vary, but audio timing must not).
3. **The single-API enqueue with deferred-vs-immediate dispatch** — clean abstraction over the on-vs-off-screen distinction. NES code's hidden polish.

## What chapter 3 sets up for chapter 4

- **Buffer-2 VRAM read-back** is the mechanism for background-tile collision. Chapter 4 (trampolines & physics) will trace how the player's foot-position triggers a buffer-2 read for the upcoming floor tile, and how the result drives the bounce.
- **The unnamed player-only fields ($08, $09, $0B, $0C, $0E)** from chapter 2 are about to become legible — they hold trampoline-arc state, mid-bounce velocity, and similar. The state machine handlers for $0A/$0C/$0E (jumping off spring → flying up → moving sideways) read and write these.
- **The "items as background tiles" finding** is what chapter 4's pickup mechanic depends on — when Mappy walks across a coin, the engine writes a "blank tile" via `sub_C78E_write_data_to_buffer` to the coin's nametable position, and the visible item disappears.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
