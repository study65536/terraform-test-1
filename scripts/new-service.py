"""Register services centrally and export independent, multi-service domain repositories."""

import argparse
import fcntl
import ipaddress
import json
import os
import re
import shutil
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path

from catalog import CATALOG, ENVS, ROOT, SERVICE_NAME, allocation, load, service_code, validate

TEMPLATE = ROOT / "service-template"
REPOSITORY = r"[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9._-]*"


def json_text(value):
    return json.dumps(value, indent=2) + "\n"


@contextmanager
def locked_directory(path):
    fd = os.open(path, os.O_RDONLY)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def register(args):
    if not SERVICE_NAME.fullmatch(args.service):
        raise ValueError("expected NN_SERVICE_NAME")
    domain = args.domain or service_code(args.service)
    with locked_directory(CATALOG.parent):
        data = load()
        if args.service in data["services"]:
            raise ValueError(f"{args.service}: already registered")
        if domain not in data["domains"]:
            if not args.owner:
                raise ValueError("a new domain requires --owner")
            data["domains"][domain] = {"owner": args.owner}
        elif args.owner and data["domains"][domain]["owner"] != args.owner:
            raise ValueError(f"{domain}: owner differs from the registered domain owner")
        if args.targets:
            if args.cidr or args.azs:
                raise ValueError("existing targets provide CIDR and AZ values")
            targets = dict(zip(ENVS, args.targets))
        else:
            if not args.cidr or not args.azs:
                raise ValueError("new targets require --cidr and --azs")
            network = ipaddress.IPv4Network(args.cidr)
            if network.prefixlen != 18:
                raise ValueError("expected an aligned /18 allocation for three /20 VPCs")
            targets = {}
            for env, account_id, subnet in zip(ENVS, args.accounts, network.subnets(new_prefix=20)):
                target = f"{service_code(args.service)}-{env}"
                if target in data["targets"]:
                    raise ValueError(f"{target}: already registered")
                data["accounts"].setdefault(account_id, {"name": target})
                data["targets"][target] = dict(
                    account_id=account_id, region=args.azs[0][:-1], environment=env,
                    availability_zones=args.azs, vpc_cidr=str(subnet), network_owner=args.service,
                )
                targets[env] = target
        data["services"][args.service] = {"domain": domain, "targets": targets}
        validate(data)
        with tempfile.TemporaryDirectory(dir=CATALOG.parent) as temporary:
            staged = Path(temporary) / CATALOG.name
            staged.write_text(json_text(data))
            staged.replace(CATALOG)
    print(f"Registered {args.service} in domain {domain}")


def domain_services(data, domain):
    if domain not in data["domains"]:
        raise ValueError(f"unknown domain {domain}")
    return sorted(name for name, spec in data["services"].items() if spec["domain"] == domain)


def pinned_references(args):
    match = re.fullmatch(rf"https://github\.com/({REPOSITORY})\.git", args.module_repo)
    if not match or not re.fullmatch(r"[a-f0-9]{40}", args.ref):
        raise ValueError("--module-repo requires an HTTPS GitHub .git URL and --ref a full lowercase SHA")
    workflow = args.workflow_repo or match[1]
    revision = args.workflow_ref or args.ref
    if args.workflow_repo and args.workflow_repo != match[1] and not args.workflow_ref:
        raise ValueError("a separate workflow repository requires its own --workflow-ref")
    if not re.fullmatch(REPOSITORY, workflow) or not re.fullmatch(r"[a-f0-9]{40}", revision):
        raise ValueError("--workflow-repo requires ORG/REPO and --workflow-ref a full lowercase SHA")
    return workflow, revision


def render(source, destination, replacements):
    text = source.read_text()
    for token, value in replacements.items():
        text = text.replace(token, value)
    destination.write_text(text)


def write_repository(stage, data, args):
    workflow, revision = pinned_references(args)
    owner = data["domains"][args.domain]["owner"]
    (stage / "domain.json").write_text(json_text({"domain": args.domain, "owner": owner}))
    gh = stage / ".github"
    (gh / "workflows").mkdir(parents=True)
    (gh / "rulesets").mkdir()
    shutil.copyfile(ROOT / "governance-template/main-review.json", gh / "rulesets/main-review.json")
    team = owner if re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", owner) else "domain-owners"
    (gh / "CODEOWNERS.example").write_text(f"* @ORG/{team}\n")
    replacements = {
        "@DOMAIN@": args.domain, "@MODULE_REPO@": args.module_repo,
        "@CI_REPO@": workflow, "@CI_REF@": revision,
    }
    render(TEMPLATE / "terraform.yml.tmpl", gh / "workflows/terraform.yml", replacements)
    render(TEMPLATE / "team-readme.md.tmpl", stage / "README.md", replacements)
    (stage / "scripts").mkdir()
    for script in TEMPLATE.glob("*.py"):
        if not script.name.startswith("test"):
            shutil.copyfile(script, stage / "scripts" / script.name)
    shutil.copyfile(ROOT / ".gitignore", stage / ".gitignore")


def write_service(stage, data, args, service):
    for env in ENVS:
        root = stage / "services" / service / env
        root.mkdir(parents=True)
        (root / "account.json").write_text(json_text(allocation(data, service, env)))
        source = f"git::{args.module_repo}//stacks/workload?ref={args.ref}"
        render(TEMPLATE / "root.tf.tmpl", root / "main.tf", {
            "@SERVICE@": service, "@ENVIRONMENT@": env, "@MODULE_SOURCE@": source,
        })
        shutil.copyfile(TEMPLATE / ".terraform.lock.hcl", root / ".terraform.lock.hcl")
        example = ROOT / "examples/services" / service / env / "workload.json"
        (root / "workload.json").write_text(example.read_text() if example.is_file() else "{}\n")


def inspect_export(output, data, args, services):
    """Return only missing services. Changes to deployed roots require an explicit review."""
    if not output.exists():
        return services
    identity = json.loads((output / "domain.json").read_text())
    if identity != {"domain": args.domain, "owner": data["domains"][args.domain]["owner"]}:
        raise ValueError("export destination belongs to a different domain or owner")
    parent = output / "services"
    if not parent.is_dir() or parent.is_symlink():
        raise ValueError("expected a local services directory in the domain checkout")
    unknown = {p.name for p in parent.iterdir() if p.is_dir()} - set(services)
    if unknown:
        raise ValueError(f"review services missing from the domain catalog: {sorted(unknown)}")
    missing = []
    for service in services:
        current = parent / service
        if current.is_symlink():
            raise ValueError(f"{current}: service directory must be local")
        if not current.exists():
            missing.append(service)
            continue
        for env in ENVS:
            if json.loads((current / env / "account.json").read_text()) != allocation(data, service, env):
                raise ValueError(f"{service}/{env}: allocation changed; review account-map before exporting")
            if not (current / env / "main.tf").is_file():
                raise ValueError(f"{service}/{env}: incomplete existing root")
    return missing


def export(args):
    data = load()
    services = domain_services(data, args.domain)
    pinned_references(args)
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        raise ValueError("choose a destination outside the platform checkout")
    output.parent.mkdir(parents=True, exist_ok=True)
    with locked_directory(output.parent):
        missing = inspect_export(output, data, args, services)
        with tempfile.TemporaryDirectory(dir=output.parent) as temporary:
            stage = Path(temporary) / "repo"
            (stage / "services").mkdir(parents=True)
            for service in missing:
                write_service(stage, data, args, service)
            if not output.exists():
                write_repository(stage, data, args)
                stage.rename(output)
            else:
                # Publish complete roots, preserving local CI, workload changes and promoted SHAs.
                moved = []
                try:
                    for service in missing:
                        source, dest = stage / "services" / service, output / "services" / service
                        source.rename(dest)
                        moved.append((source, dest))
                except OSError:
                    for source, dest in reversed(moved):
                        dest.rename(source)
                    raise
    print(f"{args.domain}: exported {len(missing)} new services to {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    signup = commands.add_parser("register", help="register a service with existing or new targets")
    signup.add_argument("service")
    signup.add_argument("--domain", help="owning domain; defaults to the service code for dedicated domains")
    signup.add_argument("--owner", help="team slug when creating a new domain")
    group = signup.add_mutually_exclusive_group(required=True)
    group.add_argument("--targets", nargs=3, metavar=("DEV", "STG", "PROD"))
    group.add_argument("--accounts", nargs=3, metavar=("DEV", "STG", "PROD"))
    signup.add_argument("--cidr")
    signup.add_argument("--azs", nargs=2, metavar=("AZ1", "AZ2"))
    generate = commands.add_parser("export", help="create or extend a domain checkout")
    generate.add_argument("domain")
    generate.add_argument("--module-repo", required=True)
    generate.add_argument("--ref", required=True)
    generate.add_argument("--workflow-repo", help="shared CI repository, ORG/REPO")
    generate.add_argument("--workflow-ref", help="shared CI repository commit SHA")
    generate.add_argument("--output", type=Path, required=True)
    snapshot = commands.add_parser("account-map", help="print one root's authoritative account.json")
    snapshot.add_argument("service")
    snapshot.add_argument("environment", choices=ENVS)
    args = parser.parse_args()
    if args.command == "register":
        register(args)
    elif args.command == "export":
        export(args)
    else:
        sys.stdout.write(json_text(allocation(load(), args.service, args.environment)))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError) as error:
        sys.exit(str(error))
