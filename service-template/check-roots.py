"""Check the generated domain's Terraform roots and state and account boundaries."""

import sys
from domain_roots import ROOT, discover

try:
    roots = discover(ROOT)
    print(f"Verified {len(roots)} service/environment roots")
except (OSError, ValueError, KeyError, TypeError) as error:
    sys.exit(str(error))
