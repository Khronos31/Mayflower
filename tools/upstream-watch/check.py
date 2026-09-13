#!/usr/bin/env python3
"""Compare Mayflower pkgver to upstream GitHub releases; open Issues when newer."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).resolve().parent / "manifest.yml"
MARKER_TMPL = "<!-- upstream-watch:pkg={pkg}:ver={ver} -->"


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def load_manifest() -> list[dict]:
    text = MANIFEST.read_text()
    if yaml is None:
        raise SystemExit("PyYAML required: pip install pyyaml")
    data = yaml.safe_load(text)
    return list(data.get("packages") or [])


def read_pkgver(pkg_id: str) -> str | None:
    mk = ROOT / "packages" / pkg_id / "make.sh"
    if not mk.is_file():
        return None
    m = re.search(r"^pkgver=([^\n#]+)", mk.read_text(), re.M)
    if not m:
        return None
    return m.group(1).strip().strip("\"'")


def parse_version_parts(v: str) -> tuple:
    v = v.strip().lstrip("v")
    parts = re.split(r"[.\-+_]", v)
    out = []
    for p in parts:
        if p.isdigit():
            out.append((0, int(p)))
            continue
        m = re.match(r"(\d+)([A-Za-z].*)?$", p)
        if m:
            out.append((0, int(m.group(1))))
            if m.group(2):
                out.append((1, m.group(2)))
        else:
            out.append((1, p))
    return tuple(out)


def is_prerelease(ver: str) -> bool:
    # 3.15.0rc2 / 3.15.0b4 / 2.56.0-rc0 / 1.0.0-beta.1 / go1.27rc1
    return bool(
        re.search(r"(?i)(?:rc|alpha|beta|preview|pre|dev)\d*", ver)
        or re.search(r"(?i)\d(?:a|b)\d+$", ver)
    )


def normalize_ruby_tag(ver: str) -> str:
    ver = ver.lstrip("v")
    if re.fullmatch(r"\d+_\d+_\d+", ver):
        return ver.replace("_", ".")
    return ver


def is_newer(upstream: str, current: str) -> bool:
    if is_prerelease(upstream) and not is_prerelease(current):
        return False
    try:
        return parse_version_parts(upstream) > parse_version_parts(current)
    except Exception:
        return upstream != current


def name_to_ver(entry: dict, name: str) -> str | None:
    prefix = entry.get("tag_prefix") or ""
    suffix = entry.get("tag_suffix") or ""
    strip_prefix = entry["strip_prefix"] if "strip_prefix" in entry else prefix
    strip_suffix = entry["strip_suffix"] if "strip_suffix" in entry else suffix
    pkg_id = entry.get("id")

    if prefix and not name.startswith(prefix):
        return None
    if suffix and not name.endswith(suffix):
        return None
    ver = name
    if strip_prefix and ver.startswith(strip_prefix):
        ver = ver[len(strip_prefix) :]
    if strip_suffix and ver.endswith(strip_suffix):
        ver = ver[: -len(strip_suffix)]
    if pkg_id == "ruby":
        ver = normalize_ruby_tag(ver)
    if pkg_id == "go" and not re.fullmatch(r"\d+(?:\.\d+)+", ver):
        return None
    if is_prerelease(ver):
        return None
    # Must look like a version (reject debug_release / wincolor-0.1.6 / release-0.7)
    if not re.fullmatch(r"\d+(?:\.\d+)+(?:[A-Za-z]+\d*)?", ver):
        return None
    return ver


def latest_upstream(entry: dict) -> tuple[str, str] | None:
    repo = entry["github"]
    pkg_id = entry.get("id")
    prefix = entry.get("tag_prefix") or ""
    candidates: list[tuple[str, str]] = []

    cp = run(
        [
            "gh",
            "api",
            f"repos/{repo}/releases?per_page=40",
            "--jq",
            ".[] | select(.draft==false and .prerelease==false) | [.tag_name,.html_url] | @tsv",
        ]
    )
    if cp.returncode == 0:
        for line in cp.stdout.splitlines():
            if "\t" not in line:
                continue
            tag, url = line.split("\t", 1)
            ver = name_to_ver(entry, tag)
            if ver:
                candidates.append((ver, url))

    ref_prefix = "go1" if pkg_id == "go" else prefix
    if ref_prefix:
        cp = run(
            [
                "gh",
                "api",
                f"repos/{repo}/git/matching-refs/tags/{ref_prefix}",
                "--jq",
                ".[].ref",
            ]
        )
        if cp.returncode == 0:
            for ref in cp.stdout.splitlines():
                name = ref.strip().removeprefix("refs/tags/")
                ver = name_to_ver(entry, name)
                if ver:
                    candidates.append((ver, f"https://github.com/{repo}/releases/tag/{name}"))
    else:
        cp = run(["gh", "api", f"repos/{repo}/tags?per_page=100", "--jq", ".[].name"])
        if cp.returncode == 0:
            for name in cp.stdout.splitlines():
                ver = name_to_ver(entry, name.strip())
                if ver:
                    candidates.append((ver, f"https://github.com/{repo}/releases/tag/{name.strip()}"))

    if not candidates:
        print(f"warn: {repo}: no matching stable tag/release", file=sys.stderr)
        return None
    return max(candidates, key=lambda x: parse_version_parts(x[0]))


def find_existing_issue(pkg: str, ver: str) -> str | None:
    marker = MARKER_TMPL.format(pkg=pkg, ver=ver)
    cp = run(
        [
            "gh",
            "issue",
            "list",
            "--repo",
            "Khronos31/Mayflower",
            "--state",
            "open",
            "--search",
            f"upstream-watch {pkg} in:body",
            "--json",
            "number,body,title",
            "--limit",
            "50",
        ]
    )
    if cp.returncode != 0:
        return None
    for issue in json.loads(cp.stdout or "[]"):
        body = issue.get("body") or ""
        title = issue.get("title") or ""
        if marker in body or title == f"upstream: {pkg} {ver}":
            return str(issue["number"])
    return None


def ensure_label() -> None:
    cp = run(["gh", "label", "list", "--repo", "Khronos31/Mayflower", "--json", "name"])
    if cp.returncode != 0:
        return
    names = {x["name"] for x in json.loads(cp.stdout or "[]")}
    if "upstream" not in names:
        run(
            [
                "gh",
                "label",
                "create",
                "upstream",
                "--repo",
                "Khronos31/Mayflower",
                "--color",
                "0052CC",
                "--description",
                "Upstream release notification",
            ]
        )


def open_issue(pkg: str, current: str, new: str, url: str, github: str) -> None:
    marker = MARKER_TMPL.format(pkg=pkg, ver=new)
    title = f"upstream: {pkg} {new}"
    body = f"""{marker}

Upstream **{github}** has **{new}** (Mayflower currently packages **{current}**).

- Release / tag: {url}
- Package tree: [`packages/{pkg}`](../tree/main/packages/{pkg})
- Docs: [`docs/{pkg}.md`](../tree/main/docs/{pkg}.md) (if present)

## Policy
Mayflower prioritizes filling Procursus gaps over routine version bumps. This issue is a **notification only** — act if useful, otherwise close / ignore.

LLVM/Clang are intentionally **not** covered by upstream-watch.

---
*Opened by `tools/upstream-watch` (GitHub Actions).*
"""
    ensure_label()
    cp = run(
        [
            "gh",
            "issue",
            "create",
            "--repo",
            "Khronos31/Mayflower",
            "--title",
            title,
            "--body",
            body,
            "--label",
            "upstream",
        ]
    )
    if cp.returncode != 0:
        cp = run(
            [
                "gh",
                "issue",
                "create",
                "--repo",
                "Khronos31/Mayflower",
                "--title",
                title,
                "--body",
                body,
            ]
        )
    print((cp.stdout or cp.stderr).strip())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only")
    args = ap.parse_args()

    pkgs = load_manifest()
    if args.only:
        pkgs = [p for p in pkgs if p["id"] == args.only]

    opened = 0
    for entry in pkgs:
        pkg = entry["id"]
        if pkg == "llvm" or "clang" in pkg:
            print(f"skip: {pkg} (excluded)")
            continue
        current = read_pkgver(pkg)
        if not current:
            print(f"skip: {pkg} (no pkgver)")
            continue
        latest = latest_upstream(entry)
        if not latest:
            continue
        new, url = latest
        print(f"{pkg}: mayflower={current} upstream={new}")
        if not is_newer(new, current):
            continue
        existing = find_existing_issue(pkg, new)
        if existing:
            print(f"  already tracked as issue #{existing}")
            continue
        print(f"  NEWER → issue for {new}")
        if args.dry_run:
            continue
        open_issue(pkg, current, new, url, entry["github"])
        opened += 1
    print(f"done; opened={opened}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
