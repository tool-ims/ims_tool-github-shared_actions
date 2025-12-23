#!/usr/bin/env python3
"""
Resolve AWS Account ID from tower + environment mapping.

Usage:
    get_account_id.py <tower> <environment>

Behavior:
- Reads mappings/aws-accounts-mapping.json
- Returns account_id to stdout
- Fails hard if mapping is missing or invalid
"""

import json
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 3:
        fail("Usage: get_account_id.py <tower> <environment>")

    tower = sys.argv[1]
    environment = sys.argv[2]

    # Resolve repo root (action/scripts/ -> repo root)
    action_dir = Path(__file__).resolve().parents[1]
    mapping_file = action_dir / "mappings" / "aws-accounts-mapping.json"

    if not mapping_file.exists():
        fail(f"Mapping file not found: {mapping_file}")

    try:
        with mapping_file.open() as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        fail(f"Invalid JSON in mapping file: {exc}")

    try:
        account_id = data[tower][environment]["account_id"]
    except KeyError:
        fail(
            f"No AWS account mapping found "
            f"(tower='{tower}', environment='{environment}')"
        )

    if not account_id:
        fail(
            f"Empty account_id value "
            f"(tower='{tower}', environment='{environment}')"
        )

    print(account_id)


if __name__ == "__main__":
    main()