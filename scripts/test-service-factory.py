"""Check shared account ownership, domain export/update and legacy state boundaries."""

import copy
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from catalog import ENVS, ROOT, validate


def sample_catalog():
    data = {"domains": {}, "accounts": {}, "targets": {}, "services": {}}
    for index, domain, service in ((1, "payments", "01_PAYMENTS"), (2, "orders", "02_ORDERS")):
        data["domains"][domain] = {"owner": f"team-{domain}"}
        targets = {}
        for n, env in enumerate(ENVS):
            account = str(100000000000 * index + n)
            name = f"{domain}-{env}"
            data["accounts"][account] = {"name": name}
            data["targets"][name] = dict(account_id=account, region="ap-northeast-2", environment=env,
                                          vpc_cidr=f"10.{10*index+n}.0.0/20", network_owner=service,
                                          availability_zones=["ap-northeast-2a", "ap-northeast-2c"])
            targets[env] = name
        data["services"][service] = {"domain": domain, "targets": targets}
    data["services"]["03_SETTLEMENT"] = copy.deepcopy(data["services"]["01_PAYMENTS"])
    return data


class ServiceFactoryTest(unittest.TestCase):
    def setUp(self):
        workspace = tempfile.TemporaryDirectory()
        self.addCleanup(workspace.cleanup)
        self.workspace = Path(workspace.name)
        self.platform = self.workspace / "platform"
        for name in ("scripts", "service-template", "catalog", "examples/services", "governance-template"):
            shutil.copytree(ROOT / name, self.platform / name, ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copyfile(ROOT / ".gitignore", self.platform / ".gitignore")
        self.catalog = self.platform / "catalog/accounts.json"
        self.catalog.write_text(json.dumps(sample_catalog()))
        self.destination = self.workspace / "payments-infra"
        self.export_args = (
            "export", "payments", "--module-repo", "https://github.com/example/library.git",
            "--ref", "1" * 40, "--output", self.destination,
        )
        self.register_args = ("register", "04_REFUNDS", "--domain", "payments", "--targets",
                              "payments-dev", "payments-stg", "payments-prod")

    def factory(self, *args, success=True):
        proc = subprocess.run([sys.executable, self.platform / "scripts/new-service.py", *args],
                              capture_output=True, text=True)
        if success:
            self.assertEqual(proc.returncode, 0, proc.stderr)
        else:
            self.assertNotEqual(proc.returncode, 0)
        return proc

    def test_shared_account_and_preserved_roots(self):
        self.factory(*self.export_args)
        services = self.destination / "services"
        self.assertEqual({p.name for p in services.iterdir()}, {"01_PAYMENTS", "03_SETTLEMENT"})
        before = services / "01_PAYMENTS/dev/main.tf"
        custom = before.read_text().replace("1" * 40, "2" * 40)
        before.write_text(custom)
        spec = services / "03_SETTLEMENT/prod/workload.json"
        spec.write_text('{"enable_bucket":false}\n')
        self.factory(*self.register_args)
        after_register = self.catalog.read_bytes()
        self.factory(*self.register_args, success=False)
        self.assertEqual(self.catalog.read_bytes(), after_register)
        self.factory(*self.export_args)
        self.factory(*self.export_args)
        self.assertEqual(before.read_text(), custom)
        self.assertEqual(spec.read_text(), '{"enable_bucket":false}\n')
        for env in ENVS:
            owner = services / "01_PAYMENTS" / env
            for service in ("01_PAYMENTS", "03_SETTLEMENT", "04_REFUNDS"):
                root = services / service / env
                account = json.loads((root / "account.json").read_text())
                self.assertEqual(account["account_id"], json.loads((owner / "account.json").read_text())["account_id"])
                self.assertEqual(account["network_owner"], "01_PAYMENTS")
                self.assertEqual(account, json.loads(self.factory("account-map", service, env).stdout))
                self.assertIn(f'"services/{service}/{env}/terraform.tfstate"', (root / "main.tf").read_text())
        self.assertTrue((self.destination / ".github/rulesets/main-review.json").is_file())
        shutil.rmtree(self.platform)
        checker = [sys.executable, self.destination / "scripts/check-roots.py"]
        subprocess.run(checker, check=True, capture_output=True)
        before.write_text(custom.replace("2" * 40, "main"))
        self.assertNotEqual(subprocess.run(checker, capture_output=True).returncode, 0)

    def test_conflict_is_atomic(self):
        self.factory(*self.export_args)
        root = self.destination / "services/03_SETTLEMENT/dev"
        account = root / "account.json"
        updated = json.loads(account.read_text())
        updated["account_id"] = "999999999999"
        account.write_text(json.dumps(updated))
        self.factory(*self.register_args)
        self.factory(*self.export_args, success=False)
        self.assertFalse((self.destination / "services/04_REFUNDS").exists())
        self.assertEqual(json.loads(account.read_text())["account_id"], "999999999999")

    def test_new_domain_allocations_and_separate_workflow_pin(self):
        args = ("register", "05_SEARCH", "--domain", "search", "--owner", "team-search",
                "--accounts", "333333333301", "333333333302", "333333333303", "--cidr", "10.30.0.0/18",
                "--azs", "ap-northeast-2a", "ap-northeast-2c")
        self.factory(*args)
        new = self.workspace / "domain"
        self.factory("export", "search", "--module-repo", "https://github.com/example/library.git",
                     "--ref", "1" * 40, "--workflow-repo", "example/workflows", "--workflow-ref",
                     "3" * 40, "--output", new)
        self.assertIn("example/workflows/.github/workflows/", (new / ".github/workflows/terraform.yml").read_text())
        self.assertIn("3" * 40, (new / ".github/workflows/terraform.yml").read_text())
        self.assertEqual(json.loads((new / "services/05_SEARCH/prod/account.json").read_text())["vpc_cidr"],
                         "10.30.32.0/20")

    def test_three_hundred_services_share_six_accounts(self):
        data = sample_catalog()
        template = data["services"]["03_SETTLEMENT"]
        # The deployed state count scales with services, while accounts and VPCs stay bounded.
        for index in range(4, 301):
            data["services"][f"{index:02d}_SERVICE{index}"] = copy.deepcopy(template)
        validate(data)
        self.assertEqual(len(data["services"]), 300)
        self.assertEqual(len(data["accounts"]), 6)
        self.assertEqual(len(data["targets"]), 6)
        for target, modifications in [
            ("payments-dev", {"network_owner": "02_ORDERS"}),
            ("orders-dev", {"vpc_cidr": data["targets"]["payments-dev"]["vpc_cidr"]}),
            ("payments-prod", {"account_id": "999999999999"}),
        ]:
            changed = copy.deepcopy(data)
            changed["targets"][target].update(modifications)
            with self.subTest(modifications=modifications):
                with self.assertRaises(ValueError):
                    validate(changed)


if __name__ == "__main__":
    unittest.main()
