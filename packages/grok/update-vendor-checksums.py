#!/usr/bin/env python3
"""Refresh .cargo-checksum.json hashes after overlaying vendor files."""
import hashlib
import json
import sys
from pathlib import Path


def main() -> int:
    vendor = Path(sys.argv[1])
    overlay = Path(sys.argv[2])
    for src in overlay.rglob("*"):
        if not src.is_file():
            continue
        rel = src.relative_to(overlay)
        dest = vendor / rel
        if not dest.is_file():
            print(f"missing overlay target: {dest}", file=sys.stderr)
            return 1
        crate = rel.parts[0]
        checksum = vendor / crate / ".cargo-checksum.json"
        if not checksum.is_file():
            print(f"missing checksum: {checksum}", file=sys.stderr)
            return 1
        key = str(Path(*rel.parts[1:]))
        digest = hashlib.sha256(dest.read_bytes()).hexdigest()
        data = json.loads(checksum.read_text())
        data.setdefault("files", {})[key] = digest
        checksum.write_text(json.dumps(data, separators=(",", ":"), ensure_ascii=False))
        print(f"checksum {crate} {key}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
