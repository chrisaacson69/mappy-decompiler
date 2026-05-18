---
status: active
created: 2026-04-26
---
# Mappy (Famicom / NES, 1984)
> Namco arcade port. NROM-128 (16 KiB PRG + 8 KiB CHR). The cleanest possible "what NES NROM can do" baseline before we hit the mapper era.

**Links:** [Game Annotation Series](../README.md), [PPU Reference](../../../research/nes/ppu-reference.md), [APU Reference](../../../research/nes/apu-reference.md), [Mappers Reference](../../../research/nes/mappers-reference.md), source: [`raw/mappy_bank_FF.asm`](../../../raw/mappy_bank_FF.asm), [`raw/mappy_bank_ram.inc`](../../../raw/mappy_bank_ram.inc), [`raw/mappy_bank_val.inc`](../../../raw/mappy_bank_val.inc)

## Why Mappy first

- **NROM-128.** Simplest cartridge — no bank switching, no IRQ, no expanded audio. The "what does the NES platform itself give you" baseline.
- **Pre-mapper era (1984).** Before MMC1/3/5 reshaped what was possible. Lets us isolate "what the chips do" from "what the cartridge enables."
- **Arcade port to home console** — Namco had to fit an arcade game (with sub-pixel positioning, smooth scrolling, multi-channel music) into 16 KiB. The compaction techniques are dense.
- **Already partially annotated.** The cyneprepou4uk disassembly gives us cross-referenced RAM, named state machine constants, and the disassembler's "I don't know what this does" markers as starting points for our work.

## Source

- **`raw/mappy_bank_FF.asm`** — full PRG bank disassembly in CA65 format. Per-line: code/data analysis flags, ROM offset, bank:address, original bytes, mnemonic, comment.
- **`raw/mappy_bank_ram.inc`** — every zero-page address documented with all its uses + cross-referenced ROM offsets.
- **`raw/mappy_bank_val.inc`** — named constants including the 16-byte object record format and the 23-state object state machine.
- Source from [cyneprepou4uk/NES-Games-Disassembly](https://github.com/cyneprepou4uk/NES-Games-Disassembly/tree/main/Mappy), Japanese version, CRC32 `3F0E8E0A`.

## Chapters

1. [Reset and frame structure](./01-reset-and-frame-structure.md) — the NES startup sequence, NMI handler, main-loop polling pattern. The capability-shift contrast vs Adventure's hand-counted DoVSYNC.
2. [The 16-byte object record & state machine](./02-object-records-and-states.md) — sub-pixel positioning, 23 states dispatched via indirect jump table, bonus-round dispatch swap, what changed when you have RAM to spend.
3. [The PPU pipeline & background-as-sprites](./03-ppu-pipeline.md) — OAMDMA, dual buffers (write queue + VRAM read-back), the single-API enqueue with deferred/immediate dispatch, garbage NOPs as audio-timing safeguards, and Mappy's signature "items live in the nametable" trick.
4. [Trampolines & physics](./04-trampolines-and-physics.md) — the bounce as a 6-state machine, tile-under-foot collision via VRAM read-back, the asymmetric "cats don't wear out trampolines" rule in 3 instructions, player-only fields decoded.
5. [Cat AI & doors as weapons](./05-cat-ai.md) — small/fat cat types, the fat cat's "hide inside item" 2-second bonus window, multi-cat sound-wave combos via per-cat door reference, the byte-meaning dispatcher finding that re-frames "player-only" fields.
6. [Game state & mode orchestration](./06-game-state.md) — the demo IS the game with replaced input, 16-round progression in 64 bytes, bonus-round dispatch swap, two-player swappable data blocks, the Namco copyright string as both legal notice AND title-screen render data. **Plus the Pac-Man design lineage.**
7. [Music & sound engine](./07-music-engine.md) — 25-voice mixer feeding 4 hardware channels, voice slot order = priority rank, 4-bytes-per-channel direct register writes. **The engine is small because the APU's autonomous envelope/sweep/length-counter units do the work.**
7. **Level data** — how rooms/floors/items are encoded; what scrolling looks like in NROM. *(planned)*
8. [Level data & bonus rounds](./08-level-data-and-bonus-rounds.md) — layered level data (palette, mansion, items, enemies, trampolines, blinking platforms), mansion-as-nametable, items-as-tiles, bonus rounds via dispatch swap, the engine-vs-content separation Namco pioneered in 1983.

## The throughline question for every chapter

Adventure's spine was *what tricks Robinett used to fit a world in 4 KB*. Mappy's spine is different:

> **What does this code do that Adventure couldn't have?**

Each chapter should make the storytelling-vs-logic shift visible — capability gained, capability still limited, and what programmers spent the new headroom on.

## LLM-interpretation log axes (Mappy edition)

Adventure's LLM log tracked three input types: structure, source comments, chip docs. Mappy adds a fourth — and clarifies a fifth:

1. **Pure structure** — same as before
2. **Disassembler's labels and cross-refs** — `vec_C031_RESET`, `ram_nmi_trigger_flag`, the documented state constants. These are *another* annotator's prior interpretation, not the original programmer's.
3. **Chip docs** — PPU, APU, NROM mapper from `research/nes/`
4. **Cumulative chapter knowledge** — same role as before, plus carrying lessons from Adventure
5. **Where the disassembler's interpretation was right / wrong / suspicious** — explicit, per chapter

The 5th axis is the discipline we owe when working over someone else's annotation. Trusting blindly is unwise; ignoring is wasteful; tracking the diff is the experiment.

## Tags

[6502](../../../tags/6502.md) · [assembly](../../../tags/assembly.md) · [reverse-engineering](../../../tags/reverse-engineering.md)
