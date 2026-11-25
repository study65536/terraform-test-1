"""Export a committed library release to a new directory or update its clean checkout."""

import argparse
import io
import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXED_FILES = {
    ".gitignore": ".gitignore",
    "modules/README.md": "modules/README.md",
    "library-template/README.md": "README.md",
    "library-template/CODEOWNERS.example": ".github/CODEOWNERS.example",
    "governance-template/main-review.json": ".github/rulesets/main-review.json",
    "library-template/.terraform.lock.hcl": ".terraform.lock.hcl",
    "library-template/terraform.yml": ".github/workflows/terraform.yml",
    ".github/workflows/reusable-domain.yml": ".github/workflows/reusable-domain.yml",
}
PACKAGE_FILE = re.compile(
    r"(?:modules/terraform-aws-[a-z0-9-]+|stacks/workload)/"
    r"(?:README\.md|[a-zA-Z0-9_-]+\.tf|tests/[a-zA-Z0-9_-]+\.tftest\.hcl)"
)


def git(cwd, *args, data=None):
    return subprocess.check_output(["git", "-C", cwd, *args], input=data)


def snapshot(revision):
    if revision.startswith("-"):
        raise ValueError("expected a commit or Git ref")
    commit = git(ROOT, "rev-parse", "--verify", revision + "^{commit}").decode().strip()
    blob = git(ROOT, "archive", "--format=tar", commit, "modules", "stacks", "library-template",
               ".gitignore", ".github/workflows/reusable-domain.yml", "governance-template/main-review.json")
    files = {"SOURCE-REVISION": (commit + "\n").encode()}
    with tarfile.open(fileobj=io.BytesIO(blob)) as archive:
        for member in archive:
            name = member.name
            dest = FIXED_FILES.get(name) or (name if PACKAGE_FILE.fullmatch(name) else None)
            if dest:
                if not member.isfile():
                    raise ValueError(f"release file must be regular: {name}")
                content = archive.extractfile(member).read()
                if dest == "README.md":
                    # The template lives one level below the kit root.
                    content = content.replace(b"](../", b"](")
                files[dest] = content
    missing = set(FIXED_FILES.values()) - files.keys()
    if missing:
        raise ValueError(f"missing release inputs at {revision}: {sorted(missing)}")
    return files


def write_files(directory, files):
    for relative, content in files.items():
        path = directory / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)


def update(output, files, temporary):
    if git(output, "rev-parse", "--show-toplevel").decode().strip() != str(output):
        raise ValueError("select the root of the standalone library checkout")
    if git(output, "status", "--porcelain", "--untracked-files=normal"):
        raise ValueError("commit or move outstanding changes in the library checkout")
    marker = output / "SOURCE-REVISION"
    if not marker.is_file() or marker.is_symlink():
        raise ValueError("existing checkout must have a library SOURCE-REVISION")
    previous = marker.read_text().strip()
    if not re.fullmatch("[a-f0-9]{40}", previous):
        raise ValueError("invalid library SOURCE-REVISION")
    base = snapshot(previous)
    for relative, original in base.items():
        path = output / relative
        if path.is_symlink() or not path.is_file() or path.read_bytes() != original:
            raise ValueError(f"reconcile local library changes before refresh: {relative}")
    if base == files:
        return
    # Construct the update against its original release. Git applies the complete
    # binary patch to tracked files and index together, checking for collisions.
    git(temporary, "init", "--quiet")
    write_files(temporary, base)
    git(temporary, "add", "-f", ".")
    old_tree = git(temporary, "write-tree").decode().strip()
    for removed in base.keys() - files.keys():
        (temporary / removed).unlink()
    write_files(temporary, files)
    git(temporary, "add", "-f", "-A", ".")
    patch = git(temporary, "diff", "--cached", "--binary", "--no-renames", old_tree)
    git(output, "apply", "--index", "--whitespace=nowarn", "-", data=patch)


def export(revision, output):
    output = output.resolve()
    if output == ROOT or ROOT in output.parents or output in ROOT.parents:
        raise ValueError("use a standalone directory outside the starter kit")
    files = snapshot(revision)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as temp:
        directory = Path(temp) / "snapshot"
        directory.mkdir()
        if output.exists():
            update(output, files, directory)
        else:
            write_files(directory, files)
            directory.rename(output)
    print(f"Library {files['SOURCE-REVISION'].decode().strip()} → {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", default="HEAD", help="starter kit commit or tag")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        export(args.ref, args.output)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
