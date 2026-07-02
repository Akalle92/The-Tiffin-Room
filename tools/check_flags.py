"""Cross-check: every flag read by scripts must be settable somewhere."""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ROOT, "data", "dialogue", "npc_data.json"), encoding="utf-8") as f:
    raw_json = f.read()

# flags set in scripts
script_raw = ""
for dirpath, _d, files in os.walk(os.path.join(ROOT, "scripts")):
    for fn in files:
        if fn.endswith(".gd"):
            with open(os.path.join(dirpath, fn), encoding="utf-8") as fh:
                script_raw += fh.read()

# flags read by Ending.gd / DayNightController / DialogueManager
read_flags = [
    "mrs_mehta_hardened", "raju_went_home", "raju_stayed_seen", "raju_hardened",
    "desai_bittersweet", "arjun_hardened", "champa_hardened",
    "babulal_words_received", "babulal_finale_played",
    "babulal_mehta_seed", "babulal_champa_seed", "champa_convergence_seen",
]

for flag in read_flags:
    in_json = f'"{flag}"' in raw_json
    in_scripts = f'"{flag}"' in script_raw
    src = []
    if in_json:
        src.append("npc_data.json")
    if in_scripts:
        src.append("scripts")
    status = " / ".join(src) if src else "NOT SET ANYWHERE (dead flag!)"
    print(f"{flag:28s} <- {status}")

# also list all set_flag / set_flags values in the json for reference
flags_in_json = sorted(set(re.findall(r'"set_flags?":\s*(?:\[)?\s*"([^"]+)"', raw_json)))
print("\nflags set in npc_data.json:", flags_in_json)
