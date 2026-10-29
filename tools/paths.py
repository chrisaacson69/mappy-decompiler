"""paths.py - where Mappy's files are, resolved from this file, never the working directory.

Every tool takes its default paths from here (emu-harness PHASES.md, Project layout), so a tool runs
the same from any cwd and a layout change is an edit to this file alone.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]      # the project root (this file is in tools/)

ROM = ROOT / "Mappy (Japan).nes"
MLB = ROOT / "Mappy (Japan).mlb"                # Mesen auto-loads it beside the ROM it opens
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
