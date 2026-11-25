"""Validate domains, AWS accounts, deployment targets and service allocations."""

import ipaddress
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "catalog/accounts.json"
ENVS = ("dev", "stg", "prod")
SERVICE_NAME = re.compile(r"[0-9]{2,}_[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*")
SLUG = re.compile(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*")


def service_code(service):
    return service.split("_", 1)[1].lower().replace("_", "-")


def validate(catalog):
    domains, accounts = catalog["domains"], catalog["accounts"]
    services, targets = catalog["services"], catalog["targets"]
    for domain, details in domains.items():
        if not SLUG.fullmatch(domain) or not details["owner"].strip():
            raise ValueError(f"{domain}: expected a domain slug and owner")

    assignments = set()
    for account_id, account in accounts.items():
        if not re.fullmatch(r"[0-9]{12}", account_id) or not account["name"].strip():
            raise ValueError(f"{account_id}: expected a 12-digit AWS account ID and name")
        key = account.get("assignment_key", account_id)
        if key in assignments or not re.fullmatch(r"[A-Za-z0-9_/-]+", key):
            raise ValueError(f"{account_id}: invalid or duplicate IAM assignment key")
        assignments.add(key)

    numbers = set()
    codes = set()
    for service, settings in services.items():
        if not SERVICE_NAME.fullmatch(service):
            raise ValueError(f"{service}: expected an NN_SERVICE identifier")
        number, code = int(service.split("_", 1)[0]), service_code(service)
        if number in numbers or code in codes:
            raise ValueError(f"{service}: duplicate service number or code")
        numbers.add(number)
        codes.add(code)
        if settings["domain"] not in domains or set(settings["targets"]) != set(ENVS):
            raise ValueError(f"{service}: expected a registered domain and dev/stg/prod mappings")
        for env, target in settings["targets"].items():
            if target not in targets or targets[target]["environment"] != env:
                raise ValueError(f"{service}/{env}: target {target} must exist in the same environment")

    networks = set()
    for target, settings in targets.items():
        env, owner = settings["environment"], settings["network_owner"]
        if not SLUG.fullmatch(target) or env not in ENVS or settings["account_id"] not in accounts:
            raise ValueError(f"{target}: invalid target name, account or environment")
        if owner not in services or services[owner]["targets"].get(env) != target:
            raise ValueError(f"{target}: network owner {owner} must deploy to this target")
        region, zones = settings["region"], settings["availability_zones"]
        if not re.fullmatch(r"[a-z]{2}(?:-[a-z0-9]+)+-[0-9]+", region):
            raise ValueError(f"{target}: invalid AWS region")
        if not isinstance(zones, list) or not 2 <= len(zones) <= 8 or len(set(zones)) != len(zones):
            raise ValueError(f"{target}: expected 2–8 distinct availability zones")
        if not all(re.fullmatch(re.escape(region) + "[a-z]", zone) for zone in zones):
            raise ValueError(f"{target}: availability zones must belong to {region}")
        cidr = ipaddress.IPv4Network(settings["vpc_cidr"])
        if cidr.prefixlen != 20 or cidr in networks:
            raise ValueError(f"{target}: expected a unique /20 VPC CIDR")
        networks.add(cidr)


def load():
    catalog = json.loads(CATALOG.read_text())
    validate(catalog)
    return catalog


def allocation(catalog, service, env):
    mapping = catalog["services"][service]
    domain, target = mapping["domain"], mapping["targets"][env]
    settings = catalog["targets"][target]
    return {
        **settings,
        "domain": domain,
        "owner": catalog["domains"][domain]["owner"],
        "target": target,
        "service_code": service_code(service),
        "network_owner_code": service_code(settings["network_owner"]),
    }


if __name__ == "__main__":
    try:
        data = load()
        print(f"Verified {len(data['domains'])} domains, {len(data['services'])} services, "
              f"{len(data['targets'])} targets and {len(data['accounts'])} AWS accounts")
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(str(error))
