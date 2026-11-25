"""Exercise isolated library publication, updates, deletions and collision handling."""
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def git(directory, *args):
    return subprocess.check_output(["git", "-C", directory, *args], text=True)


def initialize(directory):
    git(directory, "init", "-q")
    git(directory, "config", "user.email", "test@example.invalid")
    git(directory, "config", "user.name", "Local test")


def commit(directory):
    git(directory, "add", "-A")
    git(directory, "commit", "-qm", "test revision")
    return git(directory, "rev-parse", "HEAD").strip()


class LibraryRelease(unittest.TestCase):
    def test_snapshot_and_updates(self):
        with tempfile.TemporaryDirectory() as tmp:
            kit = Path(tmp) / "kit"
            library = Path(tmp) / "library"
            kit.mkdir()
            for name in ("modules", "stacks", "library-template", "governance-template", "scripts", ".github"):
                shutil.copytree(ROOT / name, kit / name, ignore=shutil.ignore_patterns("__pycache__", ".terraform", "*.tfstate*"))
            shutil.copy(ROOT / ".gitignore", kit)
            (kit / "catalog").mkdir()
            (kit / "catalog/accounts.json").write_text("private inventory")
            (kit / "modules/terraform-aws-vpc/secret.txt").write_text("private note")
            initialize(kit)
            first = commit(kit)

            def export(ref):
                return subprocess.run([sys.executable, kit / "scripts/export-library.py", "--output", library,
                                       "--ref", ref], cwd=kit, capture_output=True, text=True)

            (kit / "stacks/workload/main.tf").write_text("# uncommitted\n")
            self.assertEqual(export(first).returncode, 0)
            self.assertNotEqual((library / "stacks/workload/main.tf").read_text(), "# uncommitted\n")
            self.assertEqual((library / "SOURCE-REVISION").read_text().strip(), first)
            self.assertEqual({p.name for p in library.iterdir()}, {
                "modules", "stacks", "README.md", ".terraform.lock.hcl", ".github", ".gitignore", "SOURCE-REVISION",
            })
            self.assertFalse((library / "modules/terraform-aws-vpc/secret.txt").exists())
            self.assertTrue((library / ".github/workflows/reusable-domain.yml").exists())

            self.assertEqual((library / ".github/CODEOWNERS.example").read_bytes(),
                             (kit / "library-template/CODEOWNERS.example").read_bytes())
            self.assertEqual((library / ".github/rulesets/main-review.json").read_bytes(),
                             (kit / "governance-template/main-review.json").read_bytes())
            for document in library.rglob("*.md"):
                for url in re.findall(r"\[[^\]]*\]\(([^ )]+)\)", document.read_text()):
                    if "://" not in url and not url.startswith("#"):
                        self.assertTrue((document.parent / url.split("#")[0]).exists(),
                                        f"{document.relative_to(library)} -> {url}")

            initialize(library)
            commit(library)
            removed = "stacks/workload/tests/connectivity.tftest.hcl"
            (kit / removed).unlink()
            second = commit(kit)
            (library / "README.md").write_text("work in progress")
            self.assertNotEqual(export(second).returncode, 0)
            self.assertTrue((library / removed).exists())
            git(library, "checkout", "--", "README.md")
            self.assertEqual(export(second).returncode, 0)
            self.assertFalse((library / removed).exists())
            self.assertEqual((library / "stacks/workload/main.tf").read_text(), "# uncommitted\n")
            self.assertIn("SOURCE-REVISION", git(library, "diff", "--cached", "--name-only"))
            commit(library)
            self.assertEqual(export(second).returncode, 0)
            self.assertEqual(git(library, "status", "--porcelain"), "")


if __name__ == "__main__":
    unittest.main()
