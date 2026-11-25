import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

TEMPLATE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TEMPLATE))
spec = importlib.util.spec_from_file_location("domain_select", TEMPLATE / "select-roots.py")
selector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selector)


class ChangedRootsTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Domain CI test")
        self.git("config", "user.email", "ci@example.invalid")
        self.write("domain.json", {"domain": "payments", "owner": "payments-team"})
        self.services = ["01_PAYMENTS", "03_SETTLEMENT"]
        for service in self.services:
            for index, env in enumerate(("dev", "stg", "prod")):
                path = f"services/{service}/{env}"
                self.write(path + "/account.json", {
                    "domain": "payments", "environment": env, "service_code": service.split("_")[1].lower(),
                    "target": f"payments-{env}", "network_owner": "01_PAYMENTS", "network_owner_code": "payments",
                    "account_id": str(100000000000+index), "region": "ap-northeast-2",
                    "vpc_cidr": "10.0.0.0/20", "availability_zones": ["a", "c"],
                })
                self.write(path + "/workload.json", {})
                root_tf = (TEMPLATE / "root.tf.tmpl").read_text().replace("@SERVICE@", service).replace("@ENVIRONMENT@", env)
                root_tf = root_tf.replace("@MODULE_SOURCE@", "git::https://github.com/Org/lib.git//stacks/workload?ref=" + "a"*40)
                (self.repo / path / "main.tf").write_text(root_tf)
                shutil.copyfile(TEMPLATE / ".terraform.lock.hcl", self.repo / path / ".terraform.lock.hcl")
        self.base = self.commit()

    def write(self, name, value):
        file = self.repo / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(json.dumps(value) + "\n")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo).decode().strip()

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "test")
        return self.git("rev-parse", "HEAD")

    def test_service_change(self):
        self.write("services/01_PAYMENTS/dev/workload.json", {"enable_registry": False})
        self.commit()
        self.assertEqual(selector.select(self.repo, self.base), ["services/01_PAYMENTS/dev"])

    def test_shared_network_change(self):
        self.write("services/01_PAYMENTS/dev/workload.json", {"gateway_endpoints": ["s3"]})
        self.commit()
        self.assertEqual(selector.select(self.repo, self.base), [f"services/{s}/dev" for s in self.services])

    def test_rename_consumes_both_sides_of_diff(self):
        old = self.repo / "services/01_PAYMENTS/dev/settings.tf"
        old.write_text('variable "enabled" { default = true }\n')
        base = self.commit()
        other = self.repo / "services/03_SETTLEMENT/stg/settings.tf"
        old.rename(other)
        self.commit()
        expected = ["services/01_PAYMENTS/dev", "services/03_SETTLEMENT/dev", "services/03_SETTLEMENT/stg"]
        self.assertEqual(selector.select(self.repo, base), expected)

    def test_account_change(self):
        account = self.repo / "services/03_SETTLEMENT/stg/account.json"
        revised = json.loads(account.read_text())
        revised["owner"] = "new-team"
        self.write(str(account.relative_to(self.repo)), revised)
        self.commit()
        self.assertEqual(selector.select(self.repo, self.base), ["services/03_SETTLEMENT/stg"])

    def test_decommissioned_roots(self):
        shutil.rmtree(self.repo / "services/03_SETTLEMENT")
        self.commit()
        with self.assertRaisesRegex(ValueError, "Removed roots"):
            selector.select(self.repo, self.base)
        self.write("retired-roots.json", {f"services/03_SETTLEMENT/{env}": "migration record 15"
                                          for env in ("dev", "stg", "prod")})
        self.commit()
        self.assertEqual(len(selector.select(self.repo, self.base)), 3)

    def test_global_docs_and_batches(self):
        self.write("README.md", "example")
        self.commit()
        self.assertEqual(selector.select(self.repo, self.base), [])
        self.write("shared/provider.tf", "example")
        self.commit()
        self.assertEqual(len(selector.select(self.repo, self.base)), 6)
        large = [f"root-{i}" for i in range(900)]
        batches = selector.matrix(large)["include"]
        self.assertLessEqual(len(batches), 32)
        self.assertEqual([r for batch in batches for r in json.loads(batch["roots"])], large)


if __name__ == "__main__":
    unittest.main()
