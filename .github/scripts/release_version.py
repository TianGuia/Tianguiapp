"""Reserve a persistent build number per tag and apply it to Flutter."""

import argparse
import json
import os
import re
import subprocess
from pathlib import Path


TAG = re.compile(
    r"v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
)
VERSION = re.compile(r"^(version:[ \t]*)(\S+)([^\S\r\n]*(?:#.*)?)$", re.MULTILINE)
STATE_PATH = ".github/release-versions.json"


def metadata(tag: str, build_number: int) -> dict[str, str]:
    name, separator, code = tag.partition("+")
    if separator and code != str(build_number):
        raise ValueError("El código del tag debe coincidir con el número de compilación.")
    match = TAG.fullmatch(name)
    if not match:
        raise ValueError("El tag debe ser vX.Y.Z o X.Y.Z, con prerelease opcional.")
    prerelease = match.group(4)
    if prerelease and any(p.isdigit() and len(p) > 1 and p[0] == "0" for p in prerelease.split(".")):
        raise ValueError("Los identificadores numéricos del prerelease no admiten ceros iniciales.")
    if not 1 <= build_number <= 9999:
        raise ValueError("El contador compartido con CFBundleVersion debe estar entre 1 y 9999.")
    return {
        "version_name": name.removeprefix("v"),
        "ios_version": ".".join(match.group(i) for i in (1, 2, 3)),
        "build_number": str(build_number),
    }


def current_build(pubspec: str) -> int:
    versions = VERSION.findall(pubspec)
    if len(versions) != 1:
        raise ValueError("pubspec.yaml debe contener un solo campo version.")
    name, separator, number = versions[0][1].rpartition("+")
    if not separator or not number.isdigit():
        raise ValueError("La versión debe tener el formato X.Y.Z+numero.")
    metadata(name, int(number))
    return int(number)


def pubspec_metadata(pubspec: str) -> dict[str, str]:
    number = current_build(pubspec)
    name = VERSION.findall(pubspec)[0][1].rpartition("+")[0]
    return metadata(name, number)


def higher_pubspec(previous: str | None, current: str):
    values = pubspec_metadata(current)
    if int(values["build_number"]) <= (current_build(previous) if previous else 0):
        return None
    return values


def update_pubspec(pubspec: str, values: dict[str, str]) -> str:
    current_build(pubspec)
    version = f"{values['version_name']}+{values['build_number']}"
    return VERSION.sub(lambda match: f"{match[1]}{version}{match[3]}", pubspec)


def allocate(tag: str, pubspec: str, releases: dict[str, int]):
    current = current_build(pubspec)
    for existing_tag, number in releases.items():
        metadata(existing_tag, number)
    # Retries reuse the reservation without rolling pubspec back to an older tag.
    if tag in releases:
        return metadata(tag, releases[tag]), pubspec, dict(releases)
    values = metadata(tag, max([current, *releases.values()]) + 1)
    return values, update_pubspec(pubspec, values), {**releases, tag: int(values['build_number'])}


def git(repo: Path, *args: str, check=True):
    return subprocess.run(["git", "-C", str(repo), *args], check=check, text=True, capture_output=True)


def reserve(repo: Path, branch: str, tag: str) -> dict[str, str]:
    """Only run in the disposable Actions state checkout."""
    metadata(tag, int(tag.partition("+")[2]) if "+" in tag else 1)
    git(repo, "check-ref-format", f"refs/heads/{branch}")
    git(repo, "config", "user.name", "github-actions[bot]")
    git(repo, "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    for _ in range(5):
        # Fast-forward push is the lock: concurrent allocations retry against the
        # winning commit. Never force-push or move the original release tag.
        git(repo, "fetch", "origin", f"refs/heads/{branch}")
        git(repo, "checkout", "--detach", "--force", "FETCH_HEAD")
        pubspec_path = repo / "pubspec.yaml"
        state_path = repo / STATE_PATH
        releases = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
        values, pubspec, updated = allocate(tag, pubspec_path.read_text(encoding="utf-8"), releases)
        if tag in releases:
            return values
        pubspec_path.write_text(pubspec, encoding="utf-8")
        state_path.parent.mkdir(parents=True, exist_ok=True)
        state_path.write_text(json.dumps(updated, indent=2) + "\n", encoding="utf-8")
        git(repo, "add", "--", "pubspec.yaml", STATE_PATH)
        git(repo, "commit", "-m", f"chore: set release version {values['version_name']}+{values['build_number']}")
        pushed = git(repo, "push", "origin", f"HEAD:refs/heads/{branch}", check=False)
        if pushed.returncode == 0:
            return values
    raise RuntimeError(f"No se pudo guardar la versión en {branch}: {pushed.stderr}")


def register_pubspec(repo: Path, branch: str, values: dict[str, str], source_sha: str):
    """Record an explicit version and its source tag atomically; never bump it again."""
    tag = f"v{values['version_name']}+{values['build_number']}"
    number = int(values["build_number"])
    git(repo, "check-ref-format", f"refs/heads/{branch}")
    git(repo, "config", "user.name", "github-actions[bot]")
    git(repo, "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    for _ in range(5):
        git(repo, "fetch", "origin", f"refs/heads/{branch}")
        git(repo, "checkout", "--detach", "--force", "FETCH_HEAD")
        state_path = repo / STATE_PATH
        releases = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
        if tag in releases:
            if releases[tag] != number:
                raise ValueError("La release ya tiene otro código reservado.")
            existing = git(repo, "ls-remote", "origin", f"refs/tags/{tag}").stdout.split()
            if not existing or existing[0] != source_sha:
                raise ValueError("La release ya corresponde a otro commit.")
            return {**values, "release_tag": tag}
        # The branch may have advanced since this push. Do not release a stale
        # code or reuse one already assigned by the tag flow.
        if number <= max(releases.values(), default=0) or number < current_build((repo / "pubspec.yaml").read_text(encoding="utf-8")):
            return None
        if git(repo, "merge-base", "--is-ancestor", source_sha, "HEAD", check=False).returncode:
            return None
        state_path.parent.mkdir(parents=True, exist_ok=True)
        state_path.write_text(json.dumps({**releases, tag: number}, indent=2) + "\n", encoding="utf-8")
        git(repo, "add", "--", STATE_PATH)
        git(repo, "commit", "-m", f"chore: record release {tag}")
        # Atomic push prevents either a tag without a reservation or the reverse.
        pushed = git(repo, "push", "--atomic", "origin", f"HEAD:refs/heads/{branch}", f"{source_sha}:refs/tags/{tag}", check=False)
        if pushed.returncode == 0:
            return {**values, "release_tag": tag}
    raise RuntimeError(f"No se pudo registrar la release: {pushed.stderr}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    reservation = commands.add_parser("reserve")
    reservation.add_argument("--repo", type=Path, required=True)
    reservation.add_argument("--branch", required=True)
    reservation.add_argument("--output", type=Path, required=True)
    preparation = commands.add_parser("prepare")
    preparation.add_argument("--repo", type=Path, required=True)
    preparation.add_argument("--branch", required=True)
    preparation.add_argument("--output", type=Path, required=True)
    apply = commands.add_parser("apply")
    apply.add_argument("--metadata", type=Path, required=True)
    apply.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    args = parser.parse_args()
    if args.command == "prepare":
        if os.environ["GITHUB_REF_TYPE"] == "tag":
            tag = os.environ["GITHUB_REF_NAME"]
            values = {**reserve(args.repo, args.branch, tag), "release_tag": tag}
        else:
            event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
            before = event["before"]
            previous = None if set(before) == {"0"} else git(Path("."), "show", f"{before}:pubspec.yaml").stdout
            values = higher_pubspec(previous, Path("pubspec.yaml").read_text(encoding="utf-8"))
            if values:
                values = register_pubspec(args.repo, args.branch, values, os.environ["GITHUB_SHA"])
        with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as stream:
            stream.write(f"should_build={'true' if values else 'false'}\n")
        if values:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(values) + "\n", encoding="utf-8")
        else:
            print("El código no aumentó o ya fue utilizado; no se genera una release.")
    elif args.command == "reserve":
        tag = os.environ["RELEASE_TAG"]
        values = {**reserve(args.repo, args.branch, tag), "release_tag": tag}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(values) + "\n", encoding="utf-8")
    else:
        values = json.loads(args.metadata.read_text(encoding="utf-8"))
        expected = metadata(values["release_tag"], int(values["build_number"]))
        if {key: values[key] for key in expected} != expected:
            raise ValueError("Los metadatos no corresponden al tag de esta ejecución.")
        args.pubspec.write_text(update_pubspec(args.pubspec.read_text(encoding="utf-8"), values), encoding="utf-8")
        output = "".join(f"{key}={value}\n" for key, value in values.items())
        print(output, end="")
        with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as stream:
            stream.write(output)


if __name__ == "__main__":
    main()
