# Retired tools

What was removed, why, and how to get it back. Nothing here runs; the list exists so a session reads a
verdict instead of reviving a one-off. **Restore one:** `git show <commit>:<path> > <file>`.

| Script | Last commit | What it did | Why retired |
|---|---|---|---|
| `_assemble_record.py` | `8161d83` | Appended the 16-field object-record template (`[[obj_field]]`) to `vars.toml` from a labeling workflow's JSON output. | A one-off, already applied: it read a dead session's task file by absolute path and wrote `vars.toml` relative to the cwd. The template lives in `vars.toml`. |
