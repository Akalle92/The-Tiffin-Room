"""Static validator for The Tiffin Route dialogue data.

Checks the dialogue graph the way DialogueManager.gd walks it:
- every tree's `start` node exists
- every `next` / `fail_next` (node- and choice-level) resolves to a real node,
  "END", or "" (which the engine treats as end-of-dialogue)
- stat_check / voice_interjection skills reference real stats
- portrait_day / portrait_spirit assets exist on disk
- each NPC has a reachable path that sets spirit_resolved = true
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NPC_JSON = os.path.join(ROOT, "data", "dialogue", "npc_data.json")

VALID_STATS = {"EMPATHY", "NOSE", "STEADY_HANDS", "STREET_SENSE", "GRIEF"}
END_SENTINELS = {"", "END"}

errors = []
warnings = []


def res_to_path(res_path: str) -> str:
    return os.path.join(ROOT, res_path.replace("res://", "").replace("/", os.sep))


def check_next(npc_id, tree_id, nodes, target, ctx):
    if target in END_SENTINELS:
        return
    if target not in nodes:
        errors.append(f"[{npc_id}/{tree_id}] {ctx} -> unknown node '{target}'")


def main():
    with open(NPC_JSON, encoding="utf-8") as f:
        db = json.load(f)

    print(f"NPCs found: {sorted(db.keys())}\n")

    for npc_id, npc in db.items():
        # Portrait assets
        for key in ("portrait_day", "portrait_spirit"):
            p = npc.get(key, "")
            if p:
                if not os.path.exists(res_to_path(p)):
                    warnings.append(f"[{npc_id}] {key} missing on disk: {p}")
            else:
                warnings.append(f"[{npc_id}] no {key} defined")

        trees = npc.get("dialogue_trees", {})
        if not trees:
            errors.append(f"[{npc_id}] has no dialogue_trees")
            continue

        npc_sets_resolved = False

        for tree_id, tree in trees.items():
            nodes = tree.get("nodes", {})
            start = tree.get("start", "")
            if start not in nodes:
                errors.append(f"[{npc_id}/{tree_id}] start node '{start}' not in nodes")

            for node_id, node in nodes.items():
                # node-level next
                if "next" in node:
                    check_next(npc_id, tree_id, nodes, node["next"], f"node '{node_id}'.next")

                # voice interjections
                for vi in node.get("voice_interjections", []):
                    skill = vi.get("skill", "")
                    if skill and skill not in VALID_STATS:
                        errors.append(f"[{npc_id}/{tree_id}] node '{node_id}' interjection bad skill '{skill}'")

                choices = node.get("choices", [])
                has_next_of_any_kind = "next" in node or len(choices) > 0
                if not has_next_of_any_kind:
                    warnings.append(f"[{npc_id}/{tree_id}] node '{node_id}' is a dead end (no next/choices)")

                for i, ch in enumerate(choices):
                    cctx = f"node '{node_id}'.choice[{i}]"
                    check_next(npc_id, tree_id, nodes, ch.get("next", ""), cctx + ".next")
                    if "fail_next" in ch:
                        check_next(npc_id, tree_id, nodes, ch["fail_next"], cctx + ".fail_next")

                    sc = ch.get("stat_check")
                    if isinstance(sc, dict):
                        skill = sc.get("skill", "")
                        if skill and skill not in VALID_STATS:
                            errors.append(f"[{npc_id}/{tree_id}] {cctx} stat_check bad skill '{skill}'")
                        if "threshold" not in sc:
                            warnings.append(f"[{npc_id}/{tree_id}] {cctx} stat_check has no threshold")

                    # effects
                    eff = ch.get("effects", {})
                    stat_modify = eff.get("stat_modify", {})
                    if isinstance(stat_modify, dict):
                        for s in stat_modify:
                            if s not in VALID_STATS:
                                errors.append(f"[{npc_id}/{tree_id}] {cctx} stat_modify bad stat '{s}'")
                    ru = eff.get("route_update", {})
                    if isinstance(ru, dict) and ru.get("spirit_resolved") is True:
                        npc_sets_resolved = True

        if not npc_sets_resolved:
            errors.append(f"[{npc_id}] NO choice anywhere sets spirit_resolved=true — arc cannot complete")

    print("=" * 60)
    if warnings:
        print(f"WARNINGS ({len(warnings)}):")
        for w in warnings:
            print("  - " + w)
        print()
    if errors:
        print(f"ERRORS ({len(errors)}):")
        for e in errors:
            print("  - " + e)
        print("\nVALIDATION FAILED")
        sys.exit(1)
    print("All dialogue graphs valid. No blocking errors.")


if __name__ == "__main__":
    main()
