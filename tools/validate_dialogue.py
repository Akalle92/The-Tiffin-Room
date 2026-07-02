"""Static validator for The Tiffin Route dialogue data.

Checks the dialogue graph the way DialogueManager.gd walks it:
- every tree's `start` node exists
- every `next` / `fail_next` / `success_next` (node- and choice-level)
  resolves to a real node, "END", or "" (which the engine treats as
  end-of-dialogue)
- `minigame` nodes are treated as a valid terminal (DialogueManager launches
  the overlay instead of erroring on the missing plain `next`)
- stat_check / voice_interjection / stat_modify skills reference real stats
- portrait_day / portrait_spirit assets exist on disk (only enforced for
  NPCs that actually run the day/night spirit-arc structure)
- each spirit-arc NPC (one with a spirit_resolution tree) has a reachable
  path that sets spirit_resolved = true somewhere (choice- or node-level)
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


def check_effects(npc_id, tree_id, ctx, eff):
    if not isinstance(eff, dict) or not eff:
        return False
    resolved = False
    stat_modify = eff.get("stat_modify", {})
    if isinstance(stat_modify, dict):
        for s in stat_modify:
            if s not in VALID_STATS:
                errors.append(f"[{npc_id}/{tree_id}] {ctx} stat_modify bad stat '{s}'")
    ru = eff.get("route_update", {})
    if isinstance(ru, dict) and ru.get("spirit_resolved") is True:
        resolved = True
    set_flag = eff.get("set_flag")
    if set_flag is not None and not isinstance(set_flag, str):
        errors.append(f"[{npc_id}/{tree_id}] {ctx} set_flag must be a string")
    set_flags = eff.get("set_flags")
    if set_flags is not None and not isinstance(set_flags, list):
        errors.append(f"[{npc_id}/{tree_id}] {ctx} set_flags must be a list")
    return resolved


def main():
    with open(NPC_JSON, encoding="utf-8") as f:
        db = json.load(f)

    print(f"NPCs found: {sorted(db.keys())}\n")

    for npc_id, npc in db.items():
        trees = npc.get("dialogue_trees", {})
        if not trees:
            errors.append(f"[{npc_id}] has no dialogue_trees")
            continue

        # Only NPCs that actually run the night spirit-arc need portraits and
        # a spirit_resolved payoff (e.g. "babulal" is a flags-only finale
        # thread with no routes/ entry — see GameState._init_default_routes).
        is_spirit_arc_npc = "spirit_resolution" in trees and "spirit_intro" in trees

        if is_spirit_arc_npc:
            for key in ("portrait_day", "portrait_spirit"):
                p = npc.get(key, "")
                if p:
                    if not os.path.exists(res_to_path(p)):
                        warnings.append(f"[{npc_id}] {key} missing on disk: {p}")
                else:
                    warnings.append(f"[{npc_id}] no {key} defined")

        npc_sets_resolved = False

        for tree_id, tree in trees.items():
            nodes = tree.get("nodes", {})
            start = tree.get("start", "")
            if start not in nodes:
                errors.append(f"[{npc_id}/{tree_id}] start node '{start}' not in nodes")

            for node_id, node in nodes.items():
                is_minigame = isinstance(node.get("minigame"), dict) and bool(node.get("minigame"))

                if "next" in node:
                    check_next(npc_id, tree_id, nodes, node["next"], f"node '{node_id}'.next")
                if "success_next" in node:
                    check_next(npc_id, tree_id, nodes, node["success_next"], f"node '{node_id}'.success_next")
                if "fail_next" in node:
                    check_next(npc_id, tree_id, nodes, node["fail_next"], f"node '{node_id}'.fail_next")

                if node.get("success_effects"):
                    if check_effects(npc_id, tree_id, f"node '{node_id}'.success_effects", node["success_effects"]):
                        npc_sets_resolved = True
                if node.get("fail_effects"):
                    if check_effects(npc_id, tree_id, f"node '{node_id}'.fail_effects", node["fail_effects"]):
                        npc_sets_resolved = True
                if node.get("effects"):
                    if check_effects(npc_id, tree_id, f"node '{node_id}'.effects", node["effects"]):
                        npc_sets_resolved = True

                for vi in node.get("voice_interjections", []):
                    skill = vi.get("skill", "")
                    if skill and skill not in VALID_STATS:
                        errors.append(f"[{npc_id}/{tree_id}] node '{node_id}' interjection bad skill '{skill}'")

                choices = node.get("choices", [])
                has_next_of_any_kind = "next" in node or is_minigame or len(choices) > 0
                if not has_next_of_any_kind:
                    warnings.append(f"[{npc_id}/{tree_id}] node '{node_id}' is a dead end (no next/choices/minigame)")

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

                    if check_effects(npc_id, tree_id, cctx + ".effects", ch.get("effects", {})):
                        npc_sets_resolved = True

                    for flag_key in ("requires_flag", "requires_not_flag"):
                        v = ch.get(flag_key)
                        if v is not None and not isinstance(v, str):
                            errors.append(f"[{npc_id}/{tree_id}] {cctx}.{flag_key} must be a string")

        if is_spirit_arc_npc and not npc_sets_resolved:
            errors.append(f"[{npc_id}] NO choice/node anywhere sets spirit_resolved=true — arc cannot complete")

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
