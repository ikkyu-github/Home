#!/usr/bin/env python3
import argparse
import gzip
import sys
from pathlib import Path


def read_xcactivitylog(path: Path) -> bytes:
    data = path.read_bytes()
    # Most .xcactivitylog are gzipped.
    if data[:2] == b"\x1f\x8b":
        return gzip.decompress(data)
    return data


def main() -> int:
    ap = argparse.ArgumentParser(description="Extract readable text from an Xcode .xcactivitylog (workspace-only).")
    ap.add_argument("input", help="Path to .xcactivitylog")
    ap.add_argument("--output", help="Write extracted bytes to this file (default: stdout)")
    args = ap.parse_args()

    inp = Path(args.input)
    if not inp.exists():
        print(f"ERROR: missing input: {inp}", file=sys.stderr)
        return 2

    raw = read_xcactivitylog(inp)

    if args.output:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(raw)
        return 0

    # Best-effort: activity logs are mostly text but can contain binary.
    sys.stdout.buffer.write(raw)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
