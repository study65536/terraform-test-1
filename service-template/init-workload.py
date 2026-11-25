"""Initialize the S3 backend for one named service and environment."""

import argparse
import json
import subprocess
from domain_roots import ENVIRONMENTS, ROOT, discover

roots = discover(ROOT)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("service", choices=sorted({path.split("/")[1] for path in roots}))
parser.add_argument("environment", choices=ENVIRONMENTS)
args = parser.parse_args()
directory = f"services/{args.service}/{args.environment}"
target = roots[directory]
account, region = target["account_id"], target["region"]
subprocess.run([
    "terraform", f"-chdir={ROOT/directory}", "init", "-input=false",
    f"-backend-config=bucket=tfstate-{account}-{region}",
    f"-backend-config=region={region}", f"-backend-config=allowed_account_ids={json.dumps([account])}",
    "-lockfile=readonly",
], check=True)
