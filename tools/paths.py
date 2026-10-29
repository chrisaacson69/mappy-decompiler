"""paths.py - where Mappy's files are, resolved from this file, never the working directory.

Every tool takes its default paths from here (emu-harness PHASES.md, Project layout), so a tool runs
the same from any cwd and a layout change is an edit to this file alone.
"""
from pathlib import Path

from emu_harness.roms import find_rom

ROOT = Path(__file__).resolve().parents[1]      # the project root (this file is in tools/)

# The ROM is in the machine's ROM store (emu-harness config.toml `roms`), else this repo, and must be
# this dump: whole-file SHA-1 below; CRC32 7354615C whole, headerless SHA-1 E22B95C6...6A2256B
# (game-annotation mappy/README.md: the published disassembly's PRG and CHR, byte for byte).
ROM_NAME = "Mappy (Japan).nes"
ROM_SHA1 = "b808a6a7aee80097406c5fba7867018b7748d36e"
ROM = find_rom(ROM_NAME, ROM_SHA1, fallback=[ROOT], missing_ok=True)
MLB = ROOT / "Mappy (Japan).mlb"                # committed; mappy_mlb.py copies it beside the ROM for Mesen
LABELS = ROOT / "labels.toml"
VARS = ROOT / "vars.toml"

DISCOVER = ROOT / "source" / "0-discover"       # coverage maps, routine lists, jump / data-pointer tables
LISTING = ROOT / "source" / "1-asm-6502" / "mappy_labeled.asm"
CALLGRAPH = ROOT / "source" / "callgraph"       # call_graph.json, call_tree.txt / .html, the order, the .dot
DATA = ROOT / "assets" / "data"                 # rom_data.txt, listing_art.json
ROUNDS = ROOT / "assets" / "rounds"             # render_level's round PNGs (gitignored)
PICTURES = ROOT / "assets" / "pictures"         # render_assets' default output (gitignored)
TRACES = ROOT / "traces"                        # play logs and Mesen captures (gitignored)
SCRATCH = ROOT / "_scratch"                     # working batches (gitignored)

# The published disassembly (cyneprepou4uk/NES-Games-Disassembly), kept in the vault's raw/ as a
# grader only (pointer_tables.py's recall line); resolved by the sibling convention.
PUBLISHED_ASM = ROOT.parent / "Vault" / "raw" / "mappy_bank_FF.asm"
