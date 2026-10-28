"""Require version tags for every remote workflow and composite Action use."""

import pathlib
import re
import sys

import yaml


VERSION = re.compile(r"v[0-9]+(?:\.[0-9]+){0,2}(?:-[0-9A-Za-z.-]+)?")


def references(node):
    if isinstance(node, dict):
        if "uses" in node:
            yield node["uses"]
        for value in node.values():
            yield from references(value)
    elif isinstance(node, list):
        for value in node:
            yield from references(value)


def main(root):
    paths = sorted((root / ".github/workflows").glob("*.y*ml"))
    paths += sorted((root / ".github/actions").rglob("action.y*ml"))
    errors = []
    count = 0
    for path in paths:
        for reference in references(yaml.safe_load(path.read_text(encoding="utf-8"))):
            count += 1
            if isinstance(reference, str) and reference.startswith(("./", "$/.github/actions/")):
                continue
            if not isinstance(reference, str) or "@" not in reference or not VERSION.fullmatch(reference.rsplit("@", 1)[-1]):
                errors.append(f"{path.relative_to(root)}: {reference}: use a version tag such as @v1")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Verified {count} Action references use local paths or version tags.")
    return 0


if __name__ == "__main__":
    repository = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[2]
    sys.exit(main(repository))
