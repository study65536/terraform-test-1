"""Select domain roots affected by a Git change between a base commit and the checkout."""

import argparse
import json
import math
import re
import subprocess
import sys
from pathlib import PurePosixPath
from domain_roots import ROOT, ROOT_PATH, discover, read_json

# A change to the owner's networking or shared EKS can affect co-located consumers.
SHARED_WORKLOAD_FIELDS = {"nat_gateway_per_az", "flow_log", "gateway_endpoints", "eks", "shared_eks_cluster_name"}


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root)


def shared_change(root, base, filename):
    if filename.name != "workload.json":
        return True
    try:
        previous = json.loads(git(root, "show", f"{base}:{filename}"))
        current = read_json(root / filename)
        return any(previous.get(k) != current.get(k) for k in SHARED_WORKLOAD_FIELDS)
    except (subprocess.CalledProcessError, OSError, ValueError):
        return True


def select(root, base):
    roots = discover(root)
    if not base or base == "0" * 40:
        return sorted(roots)
    if not re.fullmatch(r"[0-9a-f]{40}", base):
        raise ValueError("Expected a full Git base commit SHA")
    # Comparing filenames without rename detection covers both the old and new path.
    files = git(root, "diff", "--no-renames", "--name-only", "-z", base, "HEAD", "--")
    changed = [PurePosixPath(name.decode()) for name in files.split(b"\0") if name]
    retired = set()
    selected = set()
    shared_owners = set()
    for file in changed:
        parts = file.parts
        key = "/".join(parts[:3])
        if ROOT_PATH.fullmatch(key):
            if key not in roots:
                if len(parts) == 4 and file.name == "main.tf":
                    retired.add(key)
                continue
            selected.add(key)
            if parts[1] == roots[key]["network_owner"] and shared_change(root, base, file):
                shared_owners.add(key)
        elif not (file.as_posix() == "README.md" or (parts[0] == "docs" and file.suffix == ".md")):
            # Common scripts, modules, policy, provider configuration or unknown paths.
            selected.update(roots)
    if retired:
        register = root / "retired-roots.json"
        records = read_json(register) if register.is_file() else {}
        missing = sorted(k for k in retired if not isinstance(records.get(k), str) or not records[k].strip())
        if missing:
            raise ValueError(f"Removed roots {missing}: record their state migration or decommission in retired-roots.json")
        selected.update(roots)
    for key, target in roots.items():
        if f"services/{target['network_owner']}/{target['environment']}" in shared_owners:
            selected.add(key)
    return sorted(selected)


def matrix(paths):
    # Up to 32 jobs even when the entire fleet changes.
    size = max(10, math.ceil(len(paths) / 32))
    return {"include": [
        {"batch": i // size + 1, "roots": json.dumps(paths[i:i+size], separators=(",", ":"))}
        for i in range(0, len(paths), size)
    ]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="previous push SHA or pull request base, omit for all roots")
    parser.add_argument("--matrix", action="store_true")
    args = parser.parse_args()
    try:
        paths = select(ROOT, args.base)
        print(json.dumps(matrix(paths) if args.matrix else paths, separators=(",", ":")))
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
