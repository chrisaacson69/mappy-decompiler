#!/usr/bin/env python3
"""merge_labels.py <results.json> - append workflow leaf-name results into labels.toml.
Accepts either the raw workflow output ({"result":[...]}) or a bare list of label dicts.
Skips addrs already present. Names come from the agents (built from behavior, no oracle)."""
import json, re, sys
from pathlib import Path
HERE = Path(__file__).parent
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
results = data["result"] if isinstance(data, dict) and "result" in data else data
labels = HERE / "labels.toml"
existing = set(x.upper() for x in re.findall(r'addr\s*=\s*"([0-9A-Fa-f]{4})"', labels.read_text(encoding="utf-8")))
def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"')
added = 0
with open(labels, "a", encoding="utf-8") as f:
    f.write("\n# --- merged from leaf-labeling workflow (agent names, behavior-derived) ---\n")
    for r in results:
        a = r["addr"].upper().replace("0X", "")[-4:]
        if a in existing: continue
        f.write("\n[[label]]\n")
        f.write(f'addr = "{a}"\n')
        f.write(f'name = "{esc(r["name"])}"\n')
        f.write(f'kind = "{r.get("kind","leaf")}"\n')
        f.write(f'conf = "{r.get("conf","")}"\n')
        f.write(f'why = "{esc(r["why"])}"\n')
        existing.add(a); added += 1
print(f"merged {added} new labels; labels.toml now has {len(existing)} entries")
