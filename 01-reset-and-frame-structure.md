---
status: active
created: 2026-04-26
---
# Mappy — Reset and Frame Structure
> The canonical NES pattern: NMI on, IRQ off, main loop polls a flag. The structural shift away from Adventure's hand-counted frame.

**Links:** [Mappy README](./README.md), [Adventure Display Kernel (comparison)](../adventure/02-display-kernel.md), [PPU Reference](../../../research/nes/ppu-reference.md), [APU Reference](../../../research/nes/apu-reference.md), source: [`raw/mappy_bank_FF.asm`](../../../raw/mappy_bank_FF.asm)

## The vector table

NROM-128's PRG ends at `$FFFF`. The 6502 reads its three vectors from the top:

```asm
.segment "VECTORS"
$FFFA: .word vec_C2EF_NMI       ; NMI (PPU VBlank) → $C2EF
$FFFC: .word vec_C031_RESET     ; Reset → $C031
$FFFE: .word vec_C304_IRQ       ; IRQ/BRK → $C304
```

Three pointers. NMI fires at the start of every PPU VBlank (provided PPUCTRL bit 7 is set). Reset fires on power or reset button. IRQ would fire on any of: APU frame IRQ, APU DMC IRQ, mapper IRQ, or `BRK` instruction. **Mappy uses none of those** — the IRQ handler at `$C304` is just an `RTI`. We'll see why below.

The whole NES platform is built around these three entry points. Compare Adventure's 6507 (no interrupts at all) — the entire reason Adventure had to hand-count frame timing was the absence of NMI. Mappy gets it for free.

## The reset handler — `vec_C031_RESET`

Walking the source from line 64. This is the canonical NES startup sequence; once you've read one, you've read most of them.

```asm
vec_C031_RESET:
       SEI                     ; mask IRQ — we don't want stray interrupts during init
       CLD                     ; clear decimal flag (no-op on 2A03; BCD is removed, but harmless)
       LDX #$5F                ; stack pointer to $5F
       TXS                     ; (so stack lives at $015F downward — only 96 bytes; the high page is reserved)
       LDA #$00
       STA $2000               ; PPUCTRL = 0 — disable NMI, default everything else
       STA $2001               ; PPUMASK = 0 — disable all rendering
bra_C03E_loop:
       LDA $2002               ; poll PPUSTATUS
       BPL bra_C03E_loop       ; loop until VBlank flag (bit 7) is set
```

**Three things to notice:**

1. **`CLD` is symbolic.** The 2A03 has BCD circuitry physically removed (chapter intro to NES research). `SED` and `CLD` set/clear the flag but arithmetic ignores it. Robinett's source on the 2600 wouldn't include `CLD` because the 6507 *does* have BCD; including it on NES is convention rather than necessity. **The code carries a habit from full-6502 systems even when the chip can't honor it.**

2. **Stack pointer is `$5F`, not `$FF`.** That puts the stack at `$015F` growing downward — only 96 bytes of stack usage allowed. The upper portion of `$0100`–`$01FF` is reserved for something else (likely a tile buffer or shadow data — chapter 2 will name it). Adventure's 2600 had the stack share 128 bytes with all variables; Mappy's NES has 2 KiB of RAM but still partitions it tightly.

3. **The polling loop on PPUSTATUS bit 7** is the **two-frame PPU warmup**. The PPU isn't in a defined state immediately after reset; it takes ~30,000 cycles (~one frame) to stabilize. The standard pattern is to poll PPUSTATUS until VBlank fires twice — but Mappy actually only does this once initially, then again later. (We'll discover the pattern fully when we trace the full init.)

Continuing:

```asm
       LDA #$07                ; high byte of $0700
       STA ram_0000_t01_data + $01
       LDA #$00                ; low byte
       STA ram_0000_t01_data
       TAY
bra_C04C_loop:                  ; clear $0100-$07FF
       STA (ram_0000_t01_data),Y
       INY
       BNE bra_C04C_loop
       DEC ram_0000_t01_data + $01
       BNE bra_C04C_loop
       
       JSR sub_C25C            ; ?
       
       LDA #$5A
       STA ram_reset_check_1   ; $003E = sentinel A
       LDA #$A5
       STA ram_reset_check_2   ; $003F = sentinel B
```

**The RAM clear** uses indirect-Y indexed addressing — the 6502 idiom for "loop over a 16-bit address space." `($93),Y` style. Adventure used the same pattern for object-data access (chapter 1's pointer pairs at `$80`–`$85`). Same chip, same idiom; bigger range here because there's more RAM.

**The `$5A` / `$A5` sentinel pair** at `$003E` / `$003F` is the **soft-reset detection trick**. The two values are bit-inverses of each other (`$5A = 0101 1010`, `$A5 = 1010 0101`). On warm reset (player presses Reset button), the RAM is *not* zeroed by hardware — it retains its contents. So if `$003E == $5A` AND `$003F == $A5` after reset, we know the previous game state is still valid; otherwise it was a cold boot. This is the same magic-number-as-state-marker pattern Adventure used for `$A2` ("no object"), here used to differentiate run modes.

Then:

```asm
       LDA #$88                ; %1000 1000
       STA $2000               ; PPUCTRL: NMI on (bit 7), BG pattern table at $1000 (bit 4)
loc_C06D_main_game_script_loop:
```

**`$88` to PPUCTRL** is the reset handler's last act before falling into the main loop. Two flags set:
- **Bit 7 (NMI enable)** — from this point on, the 2C02 will assert NMI at the start of every VBlank. The CPU's IRQ-disable flag (set by `SEI` at the start) doesn't mask NMI; NMI is non-maskable.
- **Bit 4 (BG pattern table at $1000)** — backgrounds use the second 4 KiB of CHR-ROM. Sprites stay at `$0000` (default).

After this, the CPU enters the main loop and never returns to the reset path until next reset.

## The main loop — `loc_C06D`

```asm
loc_C06D_main_game_script_loop:
bra_C06D_infinite_loop:
       LDA ram_nmi_trigger_flag       ; $20 in zero page
       BEQ bra_C06D_infinite_loop     ; tight spin until NMI sets it
       
       LDA #>ram_oam                  ; $07 — high byte of OAM shadow at $0700
       STA $4014                      ; OAMDMA — copy 256 bytes to PPU OAM
       
       JSR sub_C150_write_buffer_to_ppu_and_read_from_ppu    ; flush VRAM update queue
       JSR sub_C1C9_read_joy_regs                            ; read controller
       JSR sub_C0D0                                          ; (game logic dispatch)
       
       ; ... scroll setup ...
       LDA ram_cam_pos_X_lo
       STA ram_0010_t14_cam_pos_X_lo
       LDA ram_cam_pos_X_hi
       ; multiply camera high byte by 8 via three ROL chains:
       ASL ram_0010_t14_cam_pos_X_lo
       ROL
       ASL ram_0010_t14_cam_pos_X_lo
       ROL
       ASL ram_0010_t14_cam_pos_X_lo
       ROL
       STA $2005                      ; PPUSCROLL X (first write of latch pair)
       LDA #$00
       STA $2005                      ; PPUSCROLL Y = 0 (second write)
       LDA #$88
       ADC #$00                       ; carry from scroll math toggles nametable bit
       STA $2000                      ; PPUCTRL with possibly-toggled NN bits
       
       JSR sub_F4F1_update_sound_engine    ; tick the music engine
       
       ; ... (input/state dispatch) ...
       
       INC ram_frm_cnt                ; frame counter for game logic timing
       LDA #$00
       STA ram_nmi_trigger_flag       ; clear flag — wait for next NMI
       JMP loc_C06D_main_game_script_loop
```

This is **the** canonical NES main loop. Every NES game written for the platform's design intent looks roughly like this. Three observations:

### 1. The flag-poll pattern is the new sync primitive

Adventure had to call `JSR DoVSYNC` and inside `DoVSYNC` write to `WSYNC` repeatedly to land at known beam positions. Each frame's structure was hand-built out of `STA WSYNC` writes counted by hand (chapter 2 of Adventure).

Mappy has no `WSYNC`-equivalent. **The NMI is the heartbeat.** The PPU asserts it; the NMI handler sets `ram_nmi_trigger_flag = 1`; the main loop waits for the flag with `LDA $20 / BEQ same`. Once set, the main loop runs until `INC` clears the flag, then loops back. **Frame timing becomes "the NMI fires when it fires, and we react."**

This is the capability shift in microcosm. Adventure had to schedule its CPU around the beam; Mappy's CPU runs free and the NMI tells it when it's safe to update VRAM.

### 2. Per-frame work is staged for VBlank

Right after the flag check, the main loop does:
- `STA $4014` — OAMDMA — copies 256 bytes from `$0700`–`$07FF` to PPU OAM. Takes 513–514 CPU cycles. **This MUST happen during VBlank** — the PPU is blocked from VRAM access during DMA, and outside VBlank the OAM update would corrupt rendering.
- VRAM update queue flush — `sub_C150` walks a buffer of pending PPUDATA writes (probably tile/palette/attribute updates) and writes them. Also VBlank-only.
- Scroll setup — `STA $2005` twice + adjusted `$2000` — sets the next frame's scroll position. The PPU samples scroll values throughout the frame; timing matters.

Then the loop does game logic (input, AI dispatch, camera math, sound engine), increments `ram_frm_cnt`, clears the flag, and loops.

**Implicit discipline:** the VBlank window is ~2,273 CPU cycles. The OAMDMA alone is ~513. Buffer flush + scroll setup are a few hundred more. So the actual game logic that follows doesn't have to fit in VBlank — it runs in the *visible* region while the PPU is busy rendering. Game logic and rendering happen in parallel because they touch different chips.

This is the structural advantage Adventure couldn't have. Adventure's CPU had to feed TIA registers continuously *during* the visible region; there was no parallel-work option. Mappy's PPU does the rendering autonomously, freeing the CPU to do whatever it wants until the next NMI.

### 3. The `LDA #$88 / ADC #$00` carry-from-scroll trick

The scroll multiplication uses `ASL`/`ROL` to multiply by 8 with the high byte ending up in A. The carry flag holds bit 8 of the scrolled X coordinate. Then:

```asm
LDA #$88        ; PPUCTRL base value (NMI on, BG pattern $1000)
ADC #$00        ; add 0, but the carry from scroll math gets included
STA $2000
```

So if the scroll math overflowed, A becomes `$89` (bit 0 set) — selecting **nametable $2400 instead of $2000.** This is how horizontal scrolling toggles between nametables seamlessly. Three lines of code; uses the carry flag as an implicit channel between the scroll calculation and the PPUCTRL write.

It's the **TIA-name-as-offset trick's NES descendant** — exploiting the chip's existing semantics rather than introducing new state. Adventure repurposed register *names* as struct offsets; Mappy repurposes the *carry flag* as a nametable-select bit. Same family of move.

## The NMI handler — `vec_C2EF_NMI`

```asm
vec_C2EF_NMI:
       PHP                     ; save status
       PHA                     ; save A
       TXA
       PHA                     ; save X
       TYA
       PHA                     ; save Y
       
       ; checking flag in case of lags in the game
       ; so sound engine won't be executed twice on the same frame
       LDA ram_nmi_trigger_flag
       BEQ bra_C2FC_skip_sound_engine
       JSR sub_F4F1_update_sound_engine    ; lag frame: re-tick sound
bra_C2FC_skip_sound_engine:
       INC ram_nmi_trigger_flag           ; signal "VBlank happened"
       
       PLA                     ; restore Y
       TAY
       PLA                     ; restore X
       TAX
       PLA                     ; restore A
       PLP                     ; restore status
vec_C304_IRQ:
       RTI
```

**The NMI handler is shockingly lean.** Push registers, increment a flag, restore registers, return. ~50 cycles total in the no-sound case. The actual per-frame work happens in the *main loop body* that fires after the flag is set.

But there's a quiet sophistication in the lag-frame check: if `ram_nmi_trigger_flag` is **still nonzero** when the NMI fires, that means the main loop didn't finish processing last frame's NMI before this one fired — a **lag frame**. In that case, the handler *re-runs the sound engine* so audio doesn't stutter when the game runs slow.

This is the "audio must not glitch even when frame logic overruns" pattern. The sound engine runs from two places: the main loop (every frame, normal case) and the NMI handler (whenever there's a lag). Implementation is one byte of state (`$20`) plus a four-instruction conditional. **Adventure couldn't have done this** because there was no separate audio chip or interrupt to drive it.

Note also that **`vec_C304_IRQ` falls through to the same `RTI`.** The NMI handler's exit is also the IRQ handler. Mappy doesn't use IRQ at all, but the vector still has to be valid; the cheapest thing to point it at is the existing `RTI`. **One RTI serves both interrupt vectors.** That's a 1-byte savings every game programmer of the era used.

## Why Mappy uses no IRQ

NES IRQ sources:
- **APU frame IRQ** — fires from the APU's frame counter. Disabled by writing `$C0` to `$4017` (bit 7 = 5-step mode, bit 6 = IRQ inhibit). Mappy does this:
  ```
  LDA #$C0
  STA $4017
  ```
- **APU DMC IRQ** — only fires if DMC samples are enabled with IRQ enable bit. Mappy enables only Pulse 1/2 + Triangle + Noise (bit pattern `$0F` to `$4015`) — no DMC.
- **Mapper IRQ** — NROM has none.
- **BRK** — Mappy doesn't issue BRK.

So no IRQ source can fire. The IRQ vector just needs to exist; it doesn't need to do anything. **Hence the 1-byte handler.** Compare MMC3-era games (chapter on SMB3 someday) — those use mapper IRQ for status-bar splits and scanline tricks. Mappy's NROM has no such option.

## Cycle-budget comparison

NTSC NES: 1.79 MHz / 60 Hz = **~29,780 CPU cycles per frame**.

| Region | Mappy spends on |
|---|---|
| ~50 cycles | NMI handler (push, lag check, INC flag, pop, RTI) |
| ~513 cycles | OAMDMA |
| ~few hundred | VRAM buffer flush, scroll setup |
| ~thousands | Sound engine, joystick read, camera math |
| **~25,000+ cycles** | **Game logic — AI, physics, level scripting, animation timing** |

Compare Adventure (1.19 MHz / 60 Hz = **~19,912 cycles per frame**, of which ~5,000 were available for game logic):

| Adventure | Mappy |
|---|---|
| ~5,000 cycles for game logic per frame | **~25,000 cycles for game logic per frame** |
| Logic interleaved with display kernel via DoVSYNC | Logic runs in parallel with PPU rendering |
| Frame timing hand-counted with WSYNC | NMI provides automatic frame boundary |

**5× more CPU time for game logic.** Plus the parallel-rendering means Mappy's logic doesn't have to be interrupted; it runs as a long stream between NMI signals. This is the structural change that makes richer game state, scripted events, and music engines possible. It's the storytelling-vs-logic axis quantified.

## Efficiency catalogue (chapter 1 entries)

- **One RTI for both interrupt vectors.** NMI handler's exit is also the IRQ handler. Saves a byte (or 6) and is a universal NES idiom.
- **Lag-frame protection in the NMI.** One-byte flag, four-instruction conditional re-runs sound engine when the main loop overran. Audio doesn't stutter under load.
- **Carry-from-scroll-math as nametable-select.** `LDA #$88 / ADC #$00 / STA $2000` lets horizontal scroll naturally toggle the nametable bit. Three lines, no explicit branch.
- **Sentinel-pair soft-reset detection.** `$5A` / `$A5` at `$003E` / `$003F`. Same magic-number-as-state-marker pattern Adventure used for `$A2`, applied to "is this a warm reset?"
- **Stack at $5F means $015F downward** — 96 bytes max. The upper part of page 1 is reserved for something else (chapter 2 will name it). Tight even with 2 KiB RAM.
- **`STA $4014` is the entire OAM update.** 256 bytes copied in 513 cycles. Without OAMDMA you'd need ~768 explicit OAMDATA writes — couldn't fit in VBlank.
- **`$4017 = $C0`** disables both the frame IRQ source. With NROM having no mapper IRQ and no DMC, this leaves NMI as the only interrupt — which is exactly what Mappy wants.
- **The main loop has no explicit per-frame timer.** It runs as fast as the CPU can; the NMI flag is the *only* time discipline. Game logic sees `INC ram_frm_cnt` for its own timing.

## What this surfaces about the series

- **Adventure's chapter 2 (display kernel)** is now retroactively explained as "what you do when you don't have NMI." The whole `DoVSYNC` / `PrintDisplay` / `TidyUp` interleaving exists because the 6507 has no way to mark frame boundaries except by hand.
- **The cumulative-chapter-knowledge axis** carries forward: comparing Mappy's NMI structure to Adventure's WSYNC structure makes both clearer than reading either alone.

## LLM-interpretation log

**Pure structure was sufficient for:**
- Recognizing the canonical NES startup sequence (SEI/CLD/TXS/disable PPU/wait for VBlank/clear RAM/enable NMI).
- The flag-poll loop pattern (LDA flag / BEQ same / ... / STA #$00 to flag / JMP loop).
- The push-all/pop-all NMI handler shape.
- The OAMDMA call (LDA highbyte / STA $4014).
- The `LDA #$88 / ADC #$00` carry-from-prev-instruction trick.

**Disassembler's labels and cross-refs were decisive for:**
- Naming `vec_C2EF_NMI`, `vec_C031_RESET`, `vec_C304_IRQ` (the vector table makes these explicit, but the disassembler also flags them with `vec_` prefix).
- `ram_nmi_trigger_flag` — a one-character zero-page address would be opaque without this name.
- `loc_C06D_main_game_script_loop` — the disassembler recognized this as the game's main loop entry.
- `sub_F4F1_update_sound_engine` — without the `_update_sound_engine` suffix, the JSR target is just an address.
- The `bzk` markers (which I haven't fully exploited yet but will appear in later chapters as TODO/uncertainty markers worth tracking).

**Where I trusted vs verified vs disagreed with the disassembler:**
- **Trusted:** vector labels (verified against the explicit `.word` table), `ram_nmi_trigger_flag` semantics (verified against the canonical NMI-handler pattern).
- **Verified:** `loc_C06D` as the main loop (I traced the JMP target back to the same label — confirmed).
- **No disagreements yet.** The labels here align with standard NES idioms. If I find disagreements later, this section gets longer.

**Chip docs (PPU/APU references) were load-bearing for:**
- That `$88` to `$2000` means "NMI on + BG pattern table $1000" — straight from PPUCTRL bit layout in the [PPU reference](../../../research/nes/ppu-reference.md).
- That `$C0` to `$4017` means "5-step mode + IRQ inhibit" — straight from APU frame counter docs in the [APU reference](../../../research/nes/apu-reference.md).
- That `$0F` to `$4015` enables Pulse1/Pulse2/Triangle/Noise but not DMC — APU status register layout.
- The OAMDMA cycle cost (513–514 cycles) and the VBlank window size (~2,273 cycles).
- That NMI is non-maskable (so `SEI` doesn't disable it).

**Cumulative chapter knowledge from Adventure:**
- **The WSYNC contrast.** Without having walked Adventure's chapter 2, the *significance* of "Mappy uses NMI" wouldn't land. The main loop here looks ordinary on its own; against Adventure's hand-counted DoVSYNC, it's a paradigm shift.
- **The "magic number as state marker" pattern.** `$5A`/`$A5` sentinel pair instantly recognizable from Adventure's `$A2`-as-no-object and `$A2`-as-table-end (chapter 3 of Adventure).
- **The "exploit existing chip semantics rather than add state" pattern.** Carry-from-scroll-math reads as a Mappy-era variant of TIA-names-as-offsets — same family of move (chapter 4 of Adventure).

**Big find of chapter 1:** the structural shift isn't just "NES has more capability." It's that **logic and rendering happen in parallel** because they're on different chips, with NMI as the synchronization primitive. Adventure forced the CPU to spend most cycles painting the picture; Mappy spends ~5× more CPU time on game logic because the PPU paints autonomously. This single architectural change is what enables NES games to carry richer state machines, scripted events, and continuous music — the storytelling-as-code shift the project README posits.

## What chapter 1 sets up for chapter 2

- **The 16-byte object record** (already documented in `bank_val.inc`) — sub-pixel positions, animation, type, direction, timer, and 7 player-only extension bytes. That's where game state lives, and how Mappy's "objects" compare to Adventure's 5-byte movables.
- **The 23-state object state machine** — much richer than Adventure's dragon's 5 states. We'll see how the new CPU budget gets spent on *behavior diversity*.
- **The shadow OAM at `$0700`** — the 256-byte sprite buffer that gets DMA'd each frame. Every NES game has one of these; Mappy's structure within it is worth documenting.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
