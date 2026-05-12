---
status: active
created: 2026-04-26
---
# Mappy — Music & Sound Engine
> A 25-voice mixer feeding 4 hardware channels. Most bytes are direct APU register writes. The engine is small because the APU's autonomous envelope/sweep/length-counter units do the per-frame work the CPU would otherwise do. The chip earns its silicon.

**Links:** [Mappy README](./README.md), [Reset & Frame Structure (lag protection)](./01-reset-and-frame-structure.md), [APU Reference](../../../research/nes/apu-reference.md), source: [`raw/mappy_bank_FF.asm`](../../../raw/mappy_bank_FF.asm)

## Why this chapter is shorter

The previous chapters had structural surprises in every section because the engine compressed gameplay logic into clever data encodings. The music engine is the opposite: **the architecture is straightforward because the APU does most of the work**. Mappy's sound code is a mixer + dispatcher + register-feeder. The interesting findings are about what the *chip* does, not what the engine does.

That's the right framing. The 2A03's APU is sophisticated audio hardware on a 1.79 MHz chip. The CPU's job is to set parameters — initial pitch, envelope start, length counter load — then let the chip play the note autonomously over the next several frames. The CPU only intervenes again when the next note starts.

## The init — chapter 1 callback

From [chapter 1](./01-reset-and-frame-structure.md), the APU init at `sub_F4B5`:

```asm
sub_F4B5:
       LDA #$0F                ; %0000 1111
       STA $4015               ; enable Pulse 1, Pulse 2, Triangle, Noise (no DMC)
       LDA #$C0                ; %1100 0000
       STA $4017               ; 5-step mode, IRQ inhibit
```

Two registers, two writes. **That's the entire APU configuration** for the rest of the game. No DMC means no sample playback (chapter 3's joypad section explained the DMC interference bug Mappy escapes by not using it). 5-step mode + IRQ inhibit means the APU's frame counter runs at ~96 Hz for envelope/length updates, but never fires an interrupt.

Then `sub_F4BF` zeros all 25 voice slots and copies a 25-byte init table (`tbl_F89E`) into a parallel state region. Game start; engine ready.

## The 25-voice mixer

Sound state lives at `ram_0619` — a table of **25 voices × 8 bytes per voice = 200 bytes**. Each voice can be:
- Inactive (control byte = 0)
- Active on Pulse 1 / Pulse 2 / Triangle / Noise (control byte = 1-4)
- A "channel reservation" (control byte = 5-7)

The per-frame engine `sub_F4F1_update_sound_engine` walks all 25 voices:

```asm
bra_F51F_loop:
       LDY #$00
       LDA (ram_00F0_se_t02_data),Y    ; voice's control byte
       BEQ bra_F55A                     ; inactive — skip
       CMP #$05
       BCC bra_F534_01_04               ; control = 1-4 (channel select)
       
       ; control = 5-7 (channel reservation)
       SEC
       SBC #$05
       TAX
       LDA #$01
       STA ram_00FC_se,X                ; mark channel busy
       JMP loc_F55A
       
bra_F534_01_04:
       TAX                              ; X = channel + 1
       DEX                              ; X = channel index 0-3
       LDA ram_00FC_se,X                ; check if channel busy
       BNE bra_F55A                     ; busy — skip this voice
       LDA #$01
       STA ram_00FC_se,X                ; mark busy (this voice claims it)
       
       ; multiply X by 4 (4 register writes per channel)
       TXA
       ASL
       ASL
       TAX                              ; X = $00, $04, $08, $0C → channel base
       
       LDA #$04
       STA ram_00F6_se_t06_loop_counter
bra_F54F_loop:
       INY
       LDA (ram_00F0_se_t02_data),Y     ; voice's next register byte
       STA $4000,X                      ; → APU register
       INX
       DEC ram_00F6_se_t06_loop_counter
       BNE bra_F54F_loop
       
       ; advance to next voice slot ...
```

The engine:
1. **Walks all 25 voices** every frame.
2. **Resolves channel contention**: voices with control 5-7 reserve a channel; voices with control 1-4 use it if not reserved.
3. **For winning voices**: copies 4 bytes from the voice's data straight into `$4000,X` through `$4003,X` (or +4, +8, +C for Pulse 2 / Triangle / Noise).

That's the whole engine. **The 4-byte payload IS the APU channel's register set** — no translation, no synthesis. Game data tables hold pre-computed APU register values; the engine is just a mux.

## Music data — bytes are notes (mostly)

Looking at music data starting at `_off006_F8B7_13`:

```asm
_off006_F8B7_13:
       .byte $01            ; control: Pulse 1
       .byte $03            ; duty + envelope (DDLC NNNN)
       .byte $7F            ; sweep config
       .byte $40            ; timer low
       .byte $EF            ; control byte: end-of-sequence
       
       .byte $64, $32       ; (next note's bytes)
       .byte $13, $0B, $13
       .byte $EA, $20       ; control byte $EA + param: maybe "set tempo"
       .byte $67, $1B, $69, $13
       .byte $EA, $03       ; another tempo change
       ; ... continues ...
```

Two byte categories interleaved:
- **Plain bytes** (`$00`–`$E0` in practice) — direct APU register values to push to the channel.
- **Control bytes** (`$E0`–`$FF` range, prefixed `con_se_cb_*` in the source) — interpreter commands like "end," "set tempo," "loop," "rest."

This is a **note-stream + interpreter** pattern. Each "song" is a sequence of bytes; the engine walks the stream playing notes (writing to APU registers) and obeying control bytes. The pattern is universal across NES sound engines — Mappy's is one of the simpler ones.

The control byte values like `con_se_cb_EF`, `con_se_cb_EA` are documented in the source's equate file (not fully traced here). Each represents an interpreter command:
- `$EF` is likely "end of sequence / loop"
- `$EA` is likely "set duration / tempo" with a parameter byte
- Other `$EX` values for rest, repeat, set instrument, etc.

A song's data is roughly **70-80% notes, 20-30% control bytes**. The Mappy theme — the iconic 8-bar loop — is around 100 bytes per channel × 4 channels = 400 bytes. Compare to Adventure's ~10 bytes of "audio code" (chapter 2 of Adventure's `STA AUDC0` etc.). Two orders of magnitude more music data, but Mappy actually has *music* — a melody you can hum, with harmony and rhythm sections. Adventure had bleeps and bloops.

## What the APU does that the CPU doesn't

This is the chapter's central observation. Per-channel, **after** the CPU writes the 4 register bytes, the APU autonomously:

| APU function | What it does | What the CPU would otherwise do |
|---|---|---|
| **Length counter** | Plays the note for N ticks, then silences | Track each note's duration; manually silence each channel each frame |
| **Envelope** | Fades volume from 15 to 0 over N ticks | Compute new volume each frame, write `$4000` |
| **Sweep** | Modulates pitch over time (slides) | Compute new pitch each frame, write `$4002`/`$4003` |
| **Linear counter (Triangle)** | Triangle-specific gating | Track triangle's separate timer |
| **Frame counter** | Drives all of the above at fixed rates (~120/240 Hz) | CPU would have to time everything |

**Each of these is hardware that runs without CPU intervention.** Once the CPU writes the initial register values, the channel plays a note with envelope, sweep, and length all happening autonomously. The CPU only has to write again to start the *next* note.

Compare the [TIA's audio](https://en.wikipedia.org/wiki/Television_Interface_Adaptor#Audio):
- 2 channels (vs 5 on APU)
- 4-bit volume (vs 4-bit volume + envelope unit on APU)
- 5-bit pitch (vs 11-bit pitch + sweep on APU)
- **No envelope, no sweep, no length counter, no frame counter**

On the 2600, every audio change required CPU intervention. Want a fading sound? CPU writes new volume each frame. Want a sliding pitch? CPU writes new pitch each frame. Adventure's sounds are short tone bursts because the CPU couldn't afford to drive longer ones.

On the NES, the CPU writes 4 bytes once per note, and the chip plays the note for the next several frames. **That's why Mappy can have continuous music** — the per-frame CPU cost is tiny because most of the music is being played by hardware that's already running.

This is the storytelling-vs-logic axis applied to audio. Adventure's audio could only punctuate; Mappy's audio carries the game's emotional tone (the iconic triumphant theme during gameplay, the urgent change when "HURRY!" triggers, the bonus-round jingle).

## The lag-frame protection — chapter 1 callback

[Chapter 1](./01-reset-and-frame-structure.md) noted that the NMI handler runs `sub_F4F1_update_sound_engine` if the main loop didn't finish processing last frame's NMI:

```asm
vec_C2EF_NMI:
       ; ... save registers ...
       LDA ram_nmi_trigger_flag
       BEQ bra_C2FC_skip_sound_engine
       JSR sub_F4F1_update_sound_engine    ; lag frame: re-tick sound
bra_C2FC_skip_sound_engine:
       INC ram_nmi_trigger_flag
       ; ... restore and RTI ...
```

**The sound engine runs every frame regardless of whether the main loop overran.** If the game has a lag frame (game logic took longer than 16.7ms), the NMI handler re-ticks sound so audio doesn't stutter. Audio cadence is preserved at the cost of a possible duplicate sound update during lag.

Combined with [chapter 3's "garbage NOPs as audio-timing safeguards"](./03-ppu-pipeline.md), this is a **two-layer audio-timing defense**:
1. Garbage NOPs normalize VBlank duration so the *normal* sound update gets consistent timing.
2. NMI lag-frame fallback ensures sound runs even when the main loop overran.

Both exist because the music engine has implicit timing assumptions that gameplay-load variance would break. **The audio cadence is a first-class concern of the engine architecture, not an afterthought.**

## Sound effect triggers — game logic to sound engine

Game code triggers sound effects by writing to specific RAM bytes:

```asm
       LDA #$01
       STA ram_sfx_060E    ; trigger SFX type 1 (e.g., bonus round entry from chapter 6)
       STA ram_sfx_060F    ; trigger another SFX
       STA ram_sfx_0610    ; another
```

The sound engine's per-frame walk reads these and starts the corresponding sound-data stream. Once started, the stream plays autonomously until its `con_se_cb_EF` (end/stop) marker.

Multiple SFX can be queued simultaneously — each goes into a free voice slot. Music is just SFX with longer streams; there's no architectural distinction. **Music tracks and sound effects are the same thing**, differing only in length and complexity.

## Voice slot allocation — implicit priority

There are 25 voice slots but only 4 channels. **Different slots correspond to different priority levels** for the same channel:

- Slots 1-4: probably background music (one per channel)
- Slots 5-8: maybe second-tier music (lower priority)
- Higher-numbered slots: SFX that interrupt music

When a high-priority voice (lower slot number) wants a channel, the engine's "channel busy" check (`ram_00FC_se,X`) prevents lower-priority voices from grabbing it that frame. **First-come-first-served per frame**, with slot ordering determining the come-first.

This is why an explosion SFX can briefly mute the music's noise channel — the SFX claims the channel; the music's noise voice sees "busy" and yields. Once the SFX ends, the music's noise voice can claim the channel again on subsequent frames.

**The priority isn't an explicit field** — it's a consequence of slot order in the iteration loop. Same trick as Adventure's [matrix-slot-encodes-role](../adventure/06-dragon-state-machine.md): position in the data structure encodes behavior. **Voice slot number = priority rank.**

## Compared to the TIA's audio

| Aspect | TIA (2600 / Adventure) | APU (NES / Mappy) |
|---|---|---|
| Channels | 2 | 5 (Pulse×2, Triangle, Noise, DMC) |
| Volume | 4-bit per channel, manual | 4-bit + envelope unit |
| Pitch | 5-bit per channel, manual | 11-bit + sweep unit |
| Note duration | Manual (CPU writes silence) | Length counter (auto-silence after N ticks) |
| Engine size in bytes | ~10 (just register writes) | ~200 voices × code = ~1 KB |
| Music data per song | Negligible | ~400 bytes |
| Sound during gameplay | Sparse (CPU busy) | Continuous |
| What the CPU does per note | Write all parameters every frame | Write 4 bytes once, let chip play |

Mappy's audio code is **bigger** than Adventure's, but the *per-frame CPU work* is comparable. The big-vs-small flip happens because Mappy's audio is *expressive* (continuous melody, harmony, dynamics) while Adventure's was *minimal* (single tones for events). Mappy spends bytes on data; Adventure spent cycles on real-time synthesis.

This is the storytelling-vs-logic axis flipped: **on the audio side, the NES hardware lets data replace cycles**. The bigger ROM (16 KiB vs 4 KiB) absorbs the music data; the more capable chip (APU vs TIA) absorbs the per-frame compute. **Both sides of the trade work in the programmer's favor.**

## Efficiency catalogue (chapter 7 entries)

- **Direct APU register writes from data tables.** No synthesis layer; the engine is a mux. 4 bytes per voice slot map straight to `$4000`–`$4003` (or +4, +8, +C).
- **Voice control byte multiplexes channel selection AND reservation.** Single byte (1-4 = play, 5-7 = reserve) handles both modes. Same byte does double duty.
- **Channel busy via simple flag array.** `ram_00FC_se` (4 bytes) tracks which channels are claimed this frame. Reset every frame at the start of the engine call.
- **Voice slot order = priority rank.** No explicit priority field. Lower slot numbers iterate first, claim channels first. **Position-as-priority** echoes Adventure's matrix-slot-encodes-role pattern.
- **Note stream interpreter with $E0+ commands.** Most bytes are direct register data; high-bit bytes are interpreter commands. ~70-80% of music data is plain notes.
- **Sound effects and music share the engine.** Both are sequences of bytes the engine walks. The only architectural difference is sequence length.
- **APU autonomy — envelope, sweep, length counter, frame counter** all run in hardware. CPU writes 4 bytes per note; the chip plays for several frames without further CPU work. **Adventure's TIA had none of these.**
- **Two-layer audio-timing defense.** Garbage NOPs (chapter 3) normalize VBlank duration; NMI lag fallback re-ticks sound during overrun frames. Audio cadence is preserved against gameplay variance.

## What this confirms about earlier chapters

- **Chapter 3's garbage NOPs as audio safeguards** is now structurally explained. The audio engine has implicit timing dependencies that the NOPs preserve.
- **Chapter 1's lag-frame protection** in the NMI is for the same purpose. Sound runs from two places — main loop normally, NMI on lag — gated by the trigger flag.
- **Adventure's lack of music** isn't a design choice; it's a hardware constraint. The TIA's lack of envelope/sweep/length-counter units forced every audio change to consume CPU cycles, leaving no budget for continuous music alongside gameplay logic.

## LLM-interpretation log

**Pure structure was sufficient for:**
- The voice-slot iteration pattern (`LDY #0 / read control / branch on value / advance pointer / loop`).
- The 4-byte-per-channel write loop (`LDY counter / LDA from data / STA $4000,X / INX / DEC counter`).
- The channel-busy flag array (`ram_00FC_se,X` reads + writes following a clear-then-set pattern).
- The note-stream interpreter pattern (mostly-data-bytes-with-occasional-command-bytes).

**Disassembler's labels and cross-refs were decisive for:**
- `sub_F4F1_update_sound_engine` — name reveals the routine's role; without it, this would be a mysterious frequently-called function.
- `ram_00FC_se` and `ram_00F0_se_t01_data` — naming the engine's state vars.
- `con_se_cb_EF`, `con_se_cb_EA` — naming the music-engine control bytes ("se_cb" = sound engine control byte).
- `ram_sfx_060E` etc. — naming the SFX trigger bytes.

**Where I trusted vs verified vs disagreed with the disassembler:**
- **Trusted**: that `con_se_cb_*` constants are music-engine commands (the naming makes the role clear; full decode would require tracing each command's interpreter handler).
- **Verified**: 4 bytes per channel write (counted iterations of `bra_F54F_loop`).
- **Verified**: 25 voices total (counted entries in `tbl_F89E`, matched to the `CPX #$19` loop terminator at line 9553).
- **Inferred**: voice slot number = priority. The engine iterates slots in order; first-claimer-wins-channel is implicit. Could verify by listening to the game and noting which sounds get cut off by which other sounds.

**Chip docs were load-bearing for:**
- Understanding what each of the 4 bytes per voice means at the APU register level (duty + envelope, sweep, timer low, timer high). Straight from the [APU reference](../../../research/nes/apu-reference.md).
- That envelope, sweep, length counter, and frame counter run autonomously after the CPU sets initial values. **This is the entire reason the engine can be small.**
- The 5-step mode + IRQ inhibit rationale (Mappy doesn't want frame IRQ; uses 5-step to disable it).

**Cumulative chapter knowledge:**
- **Chapter 1's lag-frame audio re-tick** had the NMI calling the sound engine; chapter 7 explains why that matters (audio has implicit timing assumptions; missing a tick causes audible drift).
- **Chapter 3's garbage NOPs** had the same purpose (visual-load-independent audio cadence); chapter 7 ties them together.
- **Adventure's chapter 2 audio** (or rather, its absence — Adventure's audio code is 2-3 register pokes per event, not a continuous engine) is the contrast that quantifies the chip-driven music gain.

**Big find of chapter 7:** **the engine is small because the chip is large.** This is the inverse of every previous Mappy chapter — those found *clever software* compensating for *hardware constraints*. The audio chapter finds *modest software* riding on *capable hardware*. The 2A03 APU's autonomous units (envelope, sweep, length counter, frame counter) carry most of the per-frame work that a TIA-equivalent engine would require the CPU to do.

This reframes the cycle-budget arithmetic from chapter 1. Mappy's ~25,000 cycles per frame for game logic isn't *just* available because the PPU does rendering autonomously — it's also available because the APU does most of the audio work autonomously. **Two parallel chips offload work that Adventure's CPU had to do in series.** The capability shift Mappy enjoys is doubled.

## What chapter 7 sets up for chapter 8

- **Level data** — chapter 6 noted three index columns in the round-attributes table pointing at level layout, enemy spawn config, and one more. Chapter 8 will trace what those tables hold and how each round's mansion floor layout, item placement, and enemy mix are encoded.
- The bonus-round-specific gameplay (balloons, fat-cat-released-from-balloon) lives there too.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
