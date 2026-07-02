"""Check how desai/arjun (unlocked=false at start) ever become unlocked,
and simulate the full narrative loop to confirm the game is completable."""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(ROOT, "data", "dialogue", "npc_data.json"), encoding="utf-8") as f:
    db = json.load(f)

print("=== route_update payloads that touch 'unlocked' ===")
for npc_id, npc in db.items():
    for tree_id, tree in npc.get("dialogue_trees", {}).items():
        for node_id, node in tree.get("nodes", {}).items():
            payloads = []
            for ch in node.get("choices", []):
                ru = ch.get("effects", {}).get("route_update", {})
                if isinstance(ru, dict) and "unlocked" in ru:
                    payloads.append(("choice", ru))
            for k in ("effects", "success_effects", "fail_effects"):
                ru = node.get(k, {}).get("route_update", {}) if isinstance(node.get(k), dict) else {}
                if isinstance(ru, dict) and "unlocked" in ru:
                    payloads.append((k, ru))
            for kind, ru in payloads:
                print(f"  {npc_id}/{tree_id}/{node_id} [{kind}] -> {ru}")

print("\n=== NOTE: route_update applies to the CURRENT npc only ===")
print("=== so check for cross-NPC unlock mechanisms (flags?) ===")
raw = json.dumps(db)
for probe in ("desai", "arjun"):
    print(f"\n--- mentions of '{probe}' outside its own entry ---")
    for npc_id, npc in db.items():
        if npc_id == probe:
            continue
        s = json.dumps(npc)
        if probe in s:
            # find context
            idx = 0
            while True:
                idx = s.find(probe, idx)
                if idx < 0:
                    break
                print(f"  [{npc_id}] ...{s[max(0,idx-80):idx+80]}...")
                idx += 1
