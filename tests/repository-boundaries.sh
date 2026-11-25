#!/usr/bin/env bash
# Verify the reviewed commit using three independent checkouts and local Git transport.
set -euo pipefail
kit=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
library="$scratch/terraform-aws-library"
governance="$scratch/cloud-governance"
domain="$scratch/payments-infra"
library_url=https://github.com/example/terraform-aws-library.git

commit_fixture() {
  git -C "$1" add --all
  git -C "$1" -c user.name="Fixture" -c user.email=fixture@example.invalid commit --quiet -m "$2"
}

python3 "$kit/scripts/export-library.py" --ref HEAD --output "$library"
python3 "$kit/scripts/export-governance.py" --ref HEAD --output "$governance"
test -f "$library/.github/workflows/reusable-domain.yml"
test ! -e "$library/catalog"
test ! -e "$library/platform"
test ! -e "$governance/modules"
test ! -e "$governance/stacks"
git -C "$library" init --quiet
commit_fixture "$library" "Module release"
release=$(git -C "$library" rev-parse HEAD)
python3 "$governance/scripts/catalog.py"
python3 "$governance/scripts/new-service.py" export payments --module-repo "$library_url" --ref "$release" --output "$domain"
python3 "$domain/scripts/check-roots.py"
terraform fmt -check -recursive "$domain"
test ! -e "$domain/catalog"
test ! -e "$domain/platform"
grep -Fq "$release" "$domain/.github/workflows/terraform.yml"
test -f "$domain/services/01_PAYMENTS/prod/account.json"
test -f "$domain/services/03_SETTLEMENT/prod/account.json"
git -C "$domain" init --quiet
commit_fixture "$domain" "Onboard payments domain"
base=$(git -C "$domain" rev-parse HEAD)
python3 - "$domain" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1]) / "services/01_PAYMENTS/dev/workload.json"
workload = json.loads(path.read_text())
workload["enable_registry"] = not workload.get("enable_registry", True)
path.write_text(json.dumps(workload, indent=2) + "\n")
PY
commit_fixture "$domain" "Change only payments dev ECR"
python3 "$domain/scripts/select-roots.py" --base "$base" | python3 -c '
import json, sys
assert json.load(sys.stdin) == ["services/01_PAYMENTS/dev"]'
# The Terraform source is the independently committed library, fetched using its real SHA.
for env_root in "$domain"/services/*/{dev,stg,prod}; do
  git -C "$domain" -c "url.file://$library.insteadOf=$library_url" -c 'alias.run-terraform=!terraform' \
    run-terraform -chdir="$env_root" init -input=false -backend=false -lockfile=readonly >/dev/null
  if [[ "${1:-}" != "--init-only" ]]; then
    terraform -chdir="$env_root" validate
  fi
done
echo "Verified independent governance and library releases, six domain roots and single-root CI selection."
