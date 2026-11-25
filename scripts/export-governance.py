"""Bootstrap a standalone governance repository from a committed starter-kit revision."""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
# The catalog and examples are intentionally part of the private governance repository.
DIRECTORIES = ("catalog/", "platform/", "service-template/", "examples/services/")
FILES = {
    ".gitignore": ".gitignore",
    "scripts/catalog.py": "scripts/catalog.py",
    "scripts/new-service.py": "scripts/new-service.py",
    "scripts/test-service-factory.py": "scripts/test-service-factory.py",
    "governance-template/README.md": "README.md",
    "governance-template/platform.gitignore": "platform/.gitignore",
    "governance-template/CODEOWNERS.example": ".github/CODEOWNERS.example",
    "governance-template/terraform.yml": ".github/workflows/terraform.yml",
    "docs/github-standards.md": "docs/github-standards.md",
    "docs/terraform-enterprise.md": "docs/terraform-enterprise.md",
    "docs/ansible-inventory.md": "docs/ansible-inventory.md",
    "governance-template/main-review.json": "governance-template/main-review.json",
}


def git(*args):
    return subprocess.check_output(["git", "-C", ROOT, *args])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    target = args.output.resolve()
    if target.exists() or target == ROOT or ROOT in target.parents:
        parser.error("--output must be a new directory outside the starter kit")
    commit = git("rev-parse", "--verify", "--end-of-options", args.ref + "^{commit}").decode().strip()
    records = git("ls-tree", "-rz", commit).split(b"\0")
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=target.parent) as temp:
        staged = Path(temp) / "repository"
        staged.mkdir()
        included = set()
        for record in filter(None, records):
            metadata, path = record.decode().split("\t", 1)
            if path not in FILES and not path.startswith(DIRECTORIES):
                continue
            mode, kind, oid = metadata.split()
            if kind != "blob" or mode not in ("100644", "100755") or ".." in PurePosixPath(path).parts:
                raise ValueError(f"expected a regular file at {path}")
            destination = staged / FILES.get(path, path)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(git("cat-file", "blob", oid))
            destination.chmod(int(mode, 8) & 0o777)
            included.add(path)
        missing = FILES.keys() - included
        if missing:
            raise ValueError(f"revision lacks governance sources: {sorted(missing)}")
        (staged / "STARTER-REVISION").write_text(commit + "\n")
        staged.rename(target)
    print(f"Created {target} from {commit}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        sys.exit(str(exc))
