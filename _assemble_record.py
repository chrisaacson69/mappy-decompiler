import json, sys
from pathlib import Path
sys.path.insert(0, ".")
import obj_record as OR
TASKS = r"C:\Users\CHRIS~1.ISA\AppData\Local\Temp\claude\C--Users-Chris-Isaacson-Vault\3bc62c2c-2647-4125-9d63-d9e98be5501f\tasks"
d = json.loads((Path(TASKS) / "wv95mfvoz.output").read_text(encoding="utf-8"))
flds = {int(r["offset"], 16): r for r in d["result"]}

print("=== OBJECT RECORD (16 bytes, stride $10, base $0400; also reached via (obj_record_ptr),y) ===\n")
print("off  name                     conf  #rtns")
for i in range(16):
    r = flds.get(i, {})
    print(f" +{i:X}  {r.get('name','?'):24s} {r.get('conf','?'):4s}  {len(OR.fields[i])}")

def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"')[:220]
with open("vars.toml", "a", encoding="utf-8") as f:
    f.write("\n\n# === object record layout (16 bytes, base $0400 stride $10; via obj_record_ptr $1E) ===\n")
    f.write("# recovered from cross-routine field usage (obj_record.py); no external labels.\n")
    for i in range(16):
        r = flds.get(i, {})
        f.write(f'\n[[obj_field]]\noffset = "{i:02X}"\nname = "{r.get("name","")}"\nconf = "{r.get("conf","")}"\nwhy = "{esc(r.get("why",""))}"\n')
print("\nappended 16-field object-record layout to vars.toml")
