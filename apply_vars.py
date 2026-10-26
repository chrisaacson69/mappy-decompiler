#!/usr/bin/env python3
"""
apply_vars.py - write one variable-naming batch into vars.toml, regenerate the listing and the .mlb,
and check that only names changed. The variable twin of apply_names.py.

A batch file defines VARS = [(addr, name, role, conf, why), ...] and may define DROP = [addr, ...]
(variables no real instruction touches; their entries are removed, their old text kept in the
commit). A renamed entry keeps its old name and note at the end of `why`; an address with no entry
gets a new [[var]] block.

Checks: the identifier-collapse guard (walk.guard.find_guard_violations: every identifier becomes
ID and the line sequence must not change; the name-mapping guard cannot hold a name two addresses
share, which is what this pass removes), and every listing byte unchanged. On a failure vars.toml is
restored and the exit code is 2.

  apply_vars.py <batch.py>
"""
import re
import runpy
import subprocess
import sys
from pathlib import Path

from emu_harness.walk.guard import find_guard_violations
from apply_names import byte_stream

HERE = Path(__file__).parent
VARS, ASM = HERE / "vars.toml", HERE / "mappy_labeled.asm"
TOOLS = ("asm_gen.py", "mappy_mlb.py")


def var_names(text):
    return {int(a, 16): n for a, n in re.findall(r'^\[\[var\]\]\naddr = "([0-9A-F]{4})"\nname = "([^"]+)"', text, re.M)}


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def regen():
    for tool in TOOLS:
        r = subprocess.run([sys.executable, str(HERE / tool)], cwd=HERE, capture_output=True, text=True)
        if r.returncode:
            print(r.stdout, r.stderr)


def main(batch_file):
    b = runpy.run_path(batch_file)
    batch, drop = b["VARS"], b.get("DROP", [])
    regen()                                            # the baseline is a fresh regen
    before_vars, before_asm = VARS.read_text(encoding="utf-8"), ASM.read_text(encoding="utf-8")
    old = var_names(before_vars)
    blocks = re.split(r'\n(?=\[\[)', before_vars)
    out = []
    for blk in blocks:
        m = re.match(r'\[\[var\]\]\naddr = "([0-9A-F]{4})"', blk)
        if m and m.group(1) in drop:
            continue
        if m:
            for addr, name, role, conf, why in batch:
                if addr == m.group(1):
                    prior_name = re.search(r'^name = "([^"]*)"', blk, re.M).group(1)
                    prior = re.search(r'^why = "(.*)"$', blk, re.M)
                    blk = re.sub(r'^name = ".*"$', f'name = "{name}"', blk, count=1, flags=re.M)
                    blk = re.sub(r'^role = ".*"$', f'role = "{role}"', blk, count=1, flags=re.M)
                    blk = re.sub(r'^conf = ".*"$', f'conf = "{conf}"', blk, count=1, flags=re.M)
                    tail = f" Was '{prior_name}'." + (f" Earlier note: {prior.group(1)}" if prior else "")
                    blk = re.sub(r'^why = ".*"$', lambda _: f'why = "{esc(why)}{tail}"', blk, count=1, flags=re.M)
        out.append(blk)
    if [a for a in drop if int(a, 16) not in old]:
        sys.exit(f"DROP names an address with no [[var]] entry: {[a for a in drop if int(a, 16) not in old]}")
    added = [(a, n, r, c, w) for a, n, r, c, w in batch if int(a, 16) not in old]
    new_blocks = [f'[[var]]\naddr = "{a}"\nname = "{n}"\nrole = "{r}"\nconf = "{c}"\nwhy = "{esc(w)}"\n'
                  for a, n, r, c, w in added]
    first_field = next((i for i, blk in enumerate(out) if blk.startswith("[[obj_field]]")), len(out))
    out[first_field:first_field] = new_blocks          # new variables go after the last [[var]]
    text = "\n".join(out)
    VARS.write_text(text, encoding="utf-8", newline="\n")
    regen()
    after_asm = ASM.read_text(encoding="utf-8")
    # a new variable turns a raw "$44" operand into a name: treat hex literals as identifiers too (the
    # byte-stream check below still proves no address or byte changed)
    # a name also adds the "   ; $44" comment that restates the operand: drop it on both sides
    hexid = lambda t: re.sub(r'\$[0-9A-Fa-f]{2,4}\b', 'HEXID', re.sub(r'[ \t]+; \$[0-9A-Fa-f]{2,4}[ \t]*$', '', t, flags=re.M))
    others, bad = find_guard_violations({"asm": hexid(before_asm)}, {"asm": hexid(after_asm)}, {"asm"})
    if bad or byte_stream(before_asm) != byte_stream(after_asm):
        VARS.write_text(before_vars, encoding="utf-8", newline="\n")
        regen()
        print("GUARD FAILED; vars.toml restored.", bad[:3])
        sys.exit(2)
    print(f"applied {len(batch) - len(added)} variable renames, {len(added)} new, dropped {len(drop)}; "
          "byte stream unchanged; identifiers only")


if __name__ == "__main__":
    main(sys.argv[1])
