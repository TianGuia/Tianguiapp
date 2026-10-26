"""Convierte el tag y el contador de Actions en metadatos de Android e iOS."""

import os
import re
from pathlib import Path


TAG = re.compile(
    r"v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
    r"(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
)


def metadata(tag: str, run_number: int, build_base: int = 1) -> dict[str, str]:
    match = TAG.fullmatch(tag)
    if not match:
        raise ValueError("El tag debe ser vX.Y.Z o X.Y.Z, con sufijo SemVer opcional.")
    if run_number < 1 or build_base < 1:
        raise ValueError("El contador y su base deben ser enteros positivos.")
    prerelease = match.group(4)
    if prerelease and any(p.isdigit() and len(p) > 1 and p[0] == "0" for p in prerelease.split(".")):
        raise ValueError("Los identificadores numéricos del prerelease no admiten ceros iniciales.")
    build_number = build_base + run_number - 1
    if build_number > 9999:
        raise ValueError("El contador compartido con CFBundleVersion debe ser menor que 10000.")
    return {
        "version_name": tag.removeprefix("v"),
        "ios_version": ".".join(match.group(i) for i in (1, 2, 3)),
        "build_number": str(build_number),
    }


def main() -> None:
    values = metadata(
        os.environ["RELEASE_TAG"],
        int(os.environ["GITHUB_RUN_NUMBER"]),
        int(os.environ.get("RELEASE_BUILD_BASE", "1")),
    )
    output = "".join(f"{key}={value}\n" for key, value in values.items())
    print(output, end="")
    with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as stream:
        stream.write(output)


if __name__ == "__main__":
    main()
