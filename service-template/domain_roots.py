"""Shared paths and catalog snapshot checks in an exported domain repository."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENVIRONMENTS = ("dev", "stg", "prod")
SERVICE = re.compile(r"[0-9]{2,}_[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*")
ROOT_PATH = re.compile(r"services/([0-9]{2,}_[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*)/(dev|stg|prod)")
SOURCE = re.compile(
    r'^module "workload"\s*\{\s*source\s*=\s*"git::https://github\.com/'
    r'[\w.-]+/[\w.-]+\.git//stacks/workload\?ref=[0-9a-f]{40}"\s*$', re.M
)
ALLOCATED = {"vpc_cidr", "availability_zones", "shared_network_owner_code"}


def read_json(path):
    return json.loads(path.read_text())


def service_code(service):
    return service.split("_", 1)[1].lower().replace("_", "-")


def discover(root):
    domain = read_json(root / "domain.json")["domain"]
    roots = {}
    for service_dir in sorted((root / "services").iterdir()):
        if not service_dir.is_dir() or service_dir.name.startswith("."):
            continue
        service = service_dir.name
        if not SERVICE.fullmatch(service):
            raise ValueError(f"Invalid service directory: {service}")
        for env in ENVIRONMENTS:
            path = service_dir / env
            key = path.relative_to(root).as_posix()
            target = read_json(path / "account.json")
            if (target["domain"] != domain or target["environment"] != env or
                    target["service_code"] != service_code(service)):
                raise ValueError(f"{key}: unexpected domain, environment or service_code")
            if not re.fullmatch(r"[0-9]{12}", target["account_id"]):
                raise ValueError(f"{key}: expected a 12-digit AWS account ID")
            owner = target["network_owner"]
            if not SERVICE.fullmatch(owner) or target["network_owner_code"] != service_code(owner):
                raise ValueError(f"{key}: inconsistent network owner")
            main = (path / "main.tf").read_text()
            backend_key = re.escape(f"{key}/terraform.tfstate")
            if not re.search(r'^\s*key\s*=\s*"' + backend_key + r'"\s*$', main, re.M):
                raise ValueError(f"{key}: incorrect S3 backend key")
            if not SOURCE.search(main):
                raise ValueError(f"{key}: pin the workload module to a full Git commit SHA")
            if ALLOCATED & read_json(path / "workload.json").keys():
                raise ValueError(f"{key}: network allocation fields belong in account.json")
            if not (path / ".terraform.lock.hcl").is_file():
                raise ValueError(f"{key}: missing .terraform.lock.hcl")
            roots[key] = target
    if not roots:
        raise ValueError("No service environments found")
    for key, target in roots.items():
        owner = f"services/{target['network_owner']}/{target['environment']}"
        fields = ("target", "account_id", "region", "vpc_cidr", "availability_zones", "network_owner")
        if owner in roots and any(roots[owner][f] != target[f] for f in fields):
            raise ValueError(f"{key}: network owner or deployment target disagrees with {owner}")
    return roots
