"""Static validator for Godot .tscn / .tres files.

Mimics the loader rules that actually broke the build so we can catch them
without launching the editor:
- all [ext_resource] / [sub_resource] blocks must precede the first [node]
- every ExtResource("id") / SubResource("id") reference must be declared
- every ext_resource path (res://...) must exist on disk
- script paths referenced by ext_resource must exist
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ext_decl_re = re.compile(r'^\[ext_resource\s+.*id="([^"]+)"', re.M)
ext_path_re = re.compile(r'^\[ext_resource\s+.*path="([^"]+)"', re.M)
sub_decl_re = re.compile(r'^\[sub_resource\s+.*id="([^"]+)"', re.M)
ext_ref_re = re.compile(r'ExtResource\(\s*"([^"]+)"\s*\)')
sub_ref_re = re.compile(r'SubResource\(\s*"([^"]+)"\s*\)')

errors = []


def res_to_path(res_path: str) -> str:
    return os.path.join(ROOT, res_path.replace("res://", "").replace("/", os.sep))


def check_file(path: str) -> None:
    rel = os.path.relpath(path, ROOT)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    lines = text.splitlines()

    first_node = next((i for i, ln in enumerate(lines) if ln.startswith("[node")), len(lines))

    # ordering: resource blocks after first node = fatal parse error in Godot
    for i, ln in enumerate(lines):
        if i > first_node and (ln.startswith("[sub_resource") or ln.startswith("[ext_resource")):
            errors.append(f"{rel}:{i + 1} resource block after first node (Godot parse error)")

    # declared ids
    ext_ids = set(ext_decl_re.findall(text))
    sub_ids = set(sub_decl_re.findall(text))

    # referenced ids
    for ref in set(ext_ref_re.findall(text)):
        if ref not in ext_ids:
            errors.append(f"{rel}: references ExtResource(\"{ref}\") that is not declared")
    for ref in set(sub_ref_re.findall(text)):
        if ref not in sub_ids:
            errors.append(f"{rel}: references SubResource(\"{ref}\") that is not declared")

    # ext_resource paths exist on disk
    for p in ext_path_re.findall(text):
        if p.startswith("res://") and not os.path.exists(res_to_path(p)):
            errors.append(f"{rel}: ext_resource path missing on disk: {p}")


def main() -> None:
    count = 0
    for dirpath, _dirs, files in os.walk(ROOT):
        for fn in files:
            if fn.endswith((".tscn", ".tres")):
                check_file(os.path.join(dirpath, fn))
                count += 1

    print(f"Scanned {count} scene/resource files.\n")
    if errors:
        print(f"ERRORS ({len(errors)}):")
        for e in errors:
            print("  - " + e)
        sys.exit(1)
    print("All scenes/resources structurally valid.")


if __name__ == "__main__":
    main()
