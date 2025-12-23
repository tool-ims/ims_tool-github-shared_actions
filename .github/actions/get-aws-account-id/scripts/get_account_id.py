#!/usr/bin/env python3
"""
Resolve AWS Account ID from tower + environment mapping.

Usage:
    get_account_id.py <tower> <environment>

Behavior:
- Reads mappings/aws-accounts-mapping.json
- Returns account_id to stdout
- Fails hard if mapping is missing or invalid
- Prints execution/debug logs (human-readable)
"""

import json
import sys
from pathlib import Path

def log(message: str) -> None:
    print(f"[get-aws-account-id] {message}", file=sys.stderr)

def fail(message: str) -> None:
    log(f"ERROR: {message}")
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 3:
        fail("Usage: get_account_id.py <tower> <environment>")

    tower = sys.argv[1]
    environment = sys.argv[2]

    log(f"Resolving AWS account ID")
    log(f"Tower       : {tower}")
    log(f"Environment : {environment}")

    # Resolve repo root (action/scripts/ -> repo root)
    action_dir = Path(__file__).resolve().parents[1]
    mapping_file = action_dir / "mappings" / "aws-accounts-mapping.json"
    log(f"Using mapping file: {mapping_file}")

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
            f"No AWS account mapping found for"
            f"tower='{tower}', environment='{environment}'"
        )

    if not account_id:
        fail(
            f"Empty account_id for "
            f"tower='{tower}', environment='{environment}'"
        )
    log(f"Resolved account_id: {account_id}")
    print(account_id)


if __name__ == "__main__":
    main()