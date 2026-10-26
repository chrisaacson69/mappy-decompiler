#!/usr/bin/env python3
"""
apply_names.py - write one naming batch into labels.toml, regenerate the listing and the .mlb, and
check that only names changed.

A batch is a Python file defining BATCH = [(addr, name, kind, conf, why), ...]. An address that
already has a label is renamed (its old name is kept at the head of `why`); a new address gets a
new [[label]] block. Then asm_gen.py and mappy_mlb.py run, and two checks must pass:

  name mapping   emu_harness.walk.guard.name_map_violations: with every old and new routine name
                 mapped to sub_<ADDR>, the listing must be unchanged (renames only)
  byte stream    every listing line's "ADDR: BYTES" in order must be unchanged (new labels may add
                 or move label lines; no instruction or data byte may move)

On a failure labels.toml is restored and the exit code is 2 (the walk stops).

  apply_names.py <batch.py>
"""
import re
import runpy
import subprocess
import sys
from pathlib import Path

from emu_harness.walk.guard import name_map_violations

HERE = Path(__file__).parent
LABELS, ASM = HERE / "labels.toml", HERE / "mappy_labeled.asm"


def label_names(text):
    out = {}
    for m in re.finditer(r'addr\s*=\s*"([0-9A-Fa-f]{4})"\s*;?\s*\n?name\s*=\s*"([^"]+)"', text):
        out[int(m.group(1), 16)] = m.group(2)
    return out


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def byte_stream(asm):
    """{address: byte} over every listing line, however the bytes are grouped into lines (a label on
    dead code turns its .byte lines into instructions; no address may change its byte)."""
    out = {}
    for m in re.finditer(r'^\s+([0-9A-F]{4}):\s+((?:[0-9A-F]{2}(?: |$))+)', asm, re.M):
        for k, b in enumerate(m.group(2).split()):
            out[int(m.group(1), 16) + k] = b
    return out


def main(batch_file):
    batch = runpy.run_path(batch_file)["BATCH"]
    for tool in ("asm_gen.py", "mappy_mlb.py"):        # the baseline is a fresh regen, never the committed file
        subprocess.run([sys.executable, str(HERE / tool)], cwd=HERE, capture_output=True)
    before_labels = LABELS.read_text(encoding="utf-8")
    before_asm = ASM.read_text(encoding="utf-8")
    old = label_names(before_labels)
    text = before_labels
    for addr, name, kind, conf, why in batch:
        a = int(addr, 16)
        if a in old:
            rx = re.compile(r'(addr\s*=\s*"%s"\s*;?\s*\n?name\s*=\s*")[^"]+(")' % addr, re.I)
            text, n = rx.subn(lambda m: m.group(1) + name + m.group(2), text, count=1)
            assert n == 1, addr
            # the block's why: replace it, keeping the old name and old note
            i = rx.search(text).end()
            j = text.find("\n[[label]]", i)
            j = len(text) if j < 0 else j
            blk = text[i:j]
            wm = re.search(r'^why\s*=\s*"(.*)"\s*$', blk, re.M)
            prior = wm.group(1) if wm else ""
            was = "Kept (name checked against the code)." if old[a] == name else f"Was '{old[a]}'."
            new_why = f'why = "{esc(why)} {was}{(" Earlier note: " + prior) if prior else ""}"'
            blk = blk[:wm.start()] + new_why + blk[wm.end():] if wm else blk.rstrip("\n") + "\n" + new_why + "\n"
            blk = re.sub(r'(conf\s*=\s*")[^"]*(")', lambda m: m.group(1) + conf + m.group(2), blk, count=1)
            text = text[:i] + blk + text[j:]
        else:
            text = text.rstrip("\n") + (f'\n\n[[label]]\naddr = "{addr.upper()}"\nname = "{name}"\nkind = "{kind}"\n'
                                        f'conf = "{conf}"\nwhy = "{esc(why)}"\n')
    LABELS.write_text(text, encoding="utf-8", newline="\n")
    for tool in ("asm_gen.py", "mappy_mlb.py"):
        r = subprocess.run([sys.executable, str(HERE / tool)], cwd=HERE, capture_output=True, text=True)
        if r.returncode:
            print(r.stdout, r.stderr)
    after_asm = ASM.read_text(encoding="utf-8")
    new = label_names(text)
    name2tok = {n: f"sub_{a:04X}" for a, n in list(old.items()) + list(new.items())}
    bad = name_map_violations({"asm": before_asm}, {"asm": after_asm}, name2tok, is_listing=lambda fn: True)
    added = [b for b in batch if int(b[0], 16) not in old]
    stream_ok = byte_stream(before_asm) == byte_stream(after_asm)
    if (bad and not added) or not stream_ok:
        LABELS.write_text(before_labels, encoding="utf-8", newline="\n")
        for tool in ("asm_gen.py", "mappy_mlb.py"):
            subprocess.run([sys.executable, str(HERE / tool)], cwd=HERE, capture_output=True)
        print("GUARD FAILED; labels.toml restored.", "name mapping:", bad[:3], "byte stream equal:", stream_ok)
        sys.exit(2)
    print(f"applied {len(batch) - len(added)} renames, {len(added)} new labels; byte stream unchanged"
          + ("; name mapping clean" if not bad else "; name mapping differs only where new labels were added"))


if __name__ == "__main__":
    main(sys.argv[1])
