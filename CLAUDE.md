# mappy-decompiler: app-local rules

A **package in the vault's project process-table**. It obeys, outermost first:

1. **Kernel**: user-global `~/.claude/CLAUDE.md` (grounding: never fabricate, reuse/convert > rebuild,
   missing grounding means find it or ask).
2. **Project SDK**: the vault's `projects/CLAUDE.md`.
3. **emu-harness** `CLAUDE.md` and `PHASES.md`: this repo is a game adapter on that library.
4. **This file.**

## The split with game-annotation

- **Code, tables, listing, roadmap → here.** **Chapters and open-threads notes → the sibling
  `game-annotation` repo, `mappy/`.** Do not add chapter-style markdown here; a finding goes into a
  chapter there, and its numbers into `re-roadmap.toml` here.
- Pointers to the chapters are relative (`../game-annotation/mappy/...`), so both repos must be cloned
  side by side.

## Habits

- **Library code lives in emu-harness**, installed with `pip install -e ../emu-harness`. Never
  `sys.path` into it, and never copy a pass here that the library already has.
- **Generated files are regenerated, not hand-edited**: `mappy_labeled.asm` (`asm_gen.py`), the `.mlb`
  (`mappy_mlb.py`), the call graph files. Edit `labels.toml` / `vars.toml` / `listing_art.json`
  instead.
- **No ROMs, CHR, renders or emulator output in git** (`.gitignore`).
- Python is `py -3.14`.
