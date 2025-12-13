#!/usr/bin/env bash
set -euo pipefail

# This script is part of composite action repository-auto-versioning
# scripts/updateVersion.sh (centralized, verbose) 
# Usage: ./updateVersion.sh <current_version> <commits_file>
# - current_version: "X.Y.Z" or "vX.Y.Z"
# - commits_file: path containing PR title/body and commit messages separated by "###COMMIT###"
# Behaviour:
# - Implements SemVer rules: MAJOR.MINOR.PATCH
# - BREAKING CHANGE or '!' -> MAJOR
# - feat: -> MINOR
# - fix: -> PATCH
# - Precedence: MAJOR > MINOR > PATCH
# - Prepends CHANGELOG.md with "## vX.Y.Z" and list of commit subjects
# - Writes 'version' file with X.Y.Z (no leading v)
# - Outputs two important lines to stdout:
#    1) UPDATE_TYPE=<major|minor|patch>
#    2) X.Y.Z   <- final line (machine-readable new version)

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <current_version> <commits_file>" >&2
  exit 1
fi

INPUT="$1"
COMMITS_FILE="$2"

printf '[%s] updateVersion.sh start. INPUT=%s COMMITS_FILE=%s\n' \
  "$(date --iso-8601=seconds)" "$INPUT" "$COMMITS_FILE" >&2

CURRENT="${INPUT#v}"

if ! printf '%s' "$CURRENT" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Invalid semver string: $INPUT" >&2
  exit 1
fi

IFS='.' read -r CUR_MAJ CUR_MIN CUR_PATCH <<< "$CURRENT"
printf 'Parsed version MAJOR=%s MINOR=%s PATCH=%s\n' "$CUR_MAJ" "$CUR_MIN" "$CUR_PATCH" >&2

if [ ! -f "$COMMITS_FILE" ]; then
  echo "Commits file not found: $COMMITS_FILE" >&2
  exit 1
fi

# Split commit entries separated by "###COMMIT###"
mapfile -t ENTRIES < <(awk 'BEGIN{RS="###COMMIT###"} {gsub(/^[ \t\r\n]+|[ \t\r\n]+$/,""); if(length) print}' "$COMMITS_FILE")

bump_major=0
bump_minor=0
bump_patch=0
MSG_LINES=()

for e in "${ENTRIES[@]}"; do
  entry="$(printf '%s' "$e" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -z "$entry" ] && continue

  subject="$(printf '%s\n' "$entry" | head -n1)"
  printf 'Processing subject: %s\n' "$subject" >&2

  # Skip release commits (e.g., chore(release): v1.2.3)
  if printf '%s' "$subject" | grep -Eqi 'chore\(release\):\s*v?[0-9]+\.[0-9]+\.[0-9]+' ; then
    printf '  -> Skipping release-style commit\n' >&2
    continue
  fi

  # BREAKING CHANGE anywhere in entry
  if printf '%s' "$entry" | grep -qi 'BREAKING CHANGE'; then
    bump_major=1
    printf '  -> BREAKING CHANGE detected\n' >&2
  fi

  # Conventional '!' breaking (feat!:, refactor!:, or trailing '!')
  if printf '%s' "$subject" | grep -qE '^[a-zA-Z0-9]+(\([^)]+\))?!:|!$'; then
    bump_major=1
    printf '  -> "!" breaking change detected\n' >&2
  fi

  # feat -> MINOR (only if no major)
  if printf '%s' "$subject" | grep -qiE '^feat(\(|:)' ; then
    if [ "$bump_major" -eq 0 ]; then
      bump_minor=1
      printf '  -> feat detected (minor)\n' >&2
    fi
  fi

  # fix -> PATCH (if no major/minor)
  if printf '%s' "$subject" | grep -qiE '^fix(\(|:)' ; then
    if [ "$bump_major" -eq 0 ] && [ "$bump_minor" -eq 0 ]; then
      bump_patch=1
      printf '  -> fix detected (patch)\n' >&2
    fi
  fi

  MSG_LINES+=("- $subject")
done

printf 'Bump flags → major=%s minor=%s patch=%s\n' "$bump_major" "$bump_minor" "$bump_patch" >&2

# Determine bump type
if [ "$bump_major" -eq 1 ]; then
  TYPE="major"
  NEW_MAJ=$((CUR_MAJ + 1))
  NEW_MIN=0
  NEW_PAT=0
  printf 'Applying MAJOR bump\n' >&2
elif [ "$bump_minor" -eq 1 ]; then
  TYPE="minor"
  NEW_MAJ="$CUR_MAJ"
  NEW_MIN=$((CUR_MIN + 1))
  NEW_PAT=0
  printf 'Applying MINOR bump\n' >&2
elif [ "$bump_patch" -eq 1 ]; then
  TYPE="patch"
  NEW_MAJ="$CUR_MAJ"
  NEW_MIN="$CUR_MIN"
  NEW_PAT=$((CUR_PATCH + 1))
  printf 'Applying PATCH bump\n' >&2
else
  TYPE="patch"
  NEW_MAJ="$CUR_MAJ"
  NEW_MIN="$CUR_MIN"
  NEW_PAT=$((CUR_PATCH + 1))
  printf 'No bump detected → default PATCH bump\n' >&2
fi

NEW_VERSION="${NEW_MAJ}.${NEW_MIN}.${NEW_PAT}"
NEW_TAG="v${NEW_VERSION}"
printf 'Computed new_version=%s (tag=%s)\n' "$NEW_VERSION" "$NEW_TAG" >&2

# Prepend changelog entry
tmp_changelog="$(mktemp)"
trap 'rm -f "$tmp_changelog"' EXIT

{
  printf '## %s\n\n' "$NEW_TAG"
  if [ "${#MSG_LINES[@]}" -eq 0 ]; then
    echo "- (no commit subjects)"
  else
    for line in "${MSG_LINES[@]}"; do
      printf '%s\n' "$line"
    done
  fi
  printf '\n'
} > "$tmp_changelog"

[ -f CHANGELOG.md ] || touch CHANGELOG.md
cat "$tmp_changelog" CHANGELOG.md > CHANGELOG.tmp && mv CHANGELOG.tmp CHANGELOG.md

printf 'CHANGELOG.md updated\n' >&2

# Write version file (no leading v)
printf '%s\n' "$NEW_VERSION" > version
printf 'version file updated → %s\n' "$NEW_VERSION" >&2

printf '[%s] updateVersion.sh completed\n' "$(date --iso-8601=seconds)" >&2

# OUTPUT (two lines):
# 1) UPDATE_TYPE=...
# 2) X.Y.Z   (final machine-readable semver)
printf 'UPDATE_TYPE=%s\n' "$TYPE"
printf '%s\n' "$NEW_VERSION"