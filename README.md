# mappy-decompiler — Mappy (Famicom, 1984)

The working repo for reverse-engineering **Mappy** (Namco, Japan release; NROM-128: 16 KiB PRG +
8 KiB CHR). It was the first title run through all nine gated phases of
[emu-harness](https://github.com/chrisaacson69/emu-harness).

**What was found is written up elsewhere.** The chapters (reset and frame structure through the
build-tool pass) and the open-threads notes live in the
[game-annotation](https://github.com/chrisaacson69/game-annotation/tree/main/mappy) series, where
Mappy is paired with Adventure (Atari 2600). This repo holds the code, the symbol tables and the
gates behind those chapters. Start with chapter 10 (*The build-tool pass*) for the summary.

## Status

**All nine phases done (2026-10-27).** `py -3.14 -m emu_harness status mappy-decompiler` prints
each phase's gate and evidence from `re-roadmap.toml`.

| Artifact | What it is |
|---|---|
| `re-roadmap.toml` | phase status, gates, evidence; the numbers live here |
| `labels.toml` | the code symbol table (473 labels) |
| `vars.toml` | RAM variables (210) + the 16-field object-record template |
| `Mappy (Japan).mlb` | Mesen labels (`tools/mappy_mlb.py`); auto-loads next to the ROM |
| `source/1-asm-6502/mappy_labeled.asm` | the generated listing (`tools/asm_gen.py`): names, layout comments, art from `assets/data/listing_art.json` |
| `source/0-discover/` | discover's tables: routine lists, the jump tables (curated) and data-pointer tables (hand-kept), conflicts |
| `source/callgraph/` | the call graph (`call_graph.py`, `call_tree_page.py`): `call_tree.html`, `call_graph.json`, the bottom-up order |
| `assets/data/` | `rom_data.txt` (the ROM data map), `listing_art.json` |
| `tools/` | every tool; `tools/paths.py` says where everything is, so they run from any directory |

The layout is emu-harness's standard one (`PHASES.md`, Project layout). There is no `docs/`: the
chapters are in game-annotation.

**Gates:** `tools/cdl_gap.py` (CDL over real play: 0 executed bytes the listing doesn't decode),
`tools/sound_verify.py` (APU writes vs Mesen), `tools/assets_verify.py --suite` (rendered rounds vs
live VRAM), `tools/live_verify.py --suite` (the game's per-object step over live RAM). They replay the
play logs in `traces/` (gitignored; `tools/mappy_search.py` writes them).

## Setup

- `py -3.14 -m pip install -e ../emu-harness` (the sibling convention: clone both side by side).
- Supply your own ROM as `Mappy (Japan).nes` in this folder. ROMs, CHR, renders (`*.png`), rendered
  sound (`assets/sound/`), captures (`traces/`) and `_scratch/` are gitignored: they are copyrighted
  or regenerable.
- Pictures: `tools/render_assets.py [OUT_DIR]` (default `assets/pictures/`); rounds:
  `tools/render_level.py 0 1 ...` (`assets/rounds/`). Sounds: `tools/sound_capture.py --wav DIR`.

## History

Split out of `game-annotation/mappy/` on 2026-10-27 with its history (`git subtree split`), because
emu-harness keeps each game's adapter in that game's own repo. Commit hashes written inside
`re-roadmap.toml` as "game-annotation <hash>" refer to that repo's history, not this one.
