# repository-auto-versioning: Unified Versioning System for Git Repositories

A complete, production-grade framework for automated **semantic versioning**, **CHANGELOG generation**, and **Git tag publishing** triggered on every Pull Request merge.

---
# Table of Contents

1. [Overview](#overview)
2. [Architecture Overview](#architecture-overview)
3. [Semantic Versioning Rules](#semantic-versioning-rules)
4. [Precedence (important)](#precedence-important)
5. [Skip CI Detection (title, body, commits)](#skip-ci-detection-title-body-commits)
6. [Repo-Level Workflow (`repository-versioning.yml`)](#repo-level-workflow-repository-versioningyml)
7. [Composite Action (`repository-auto-versioning`)](#composite-action-repository-auto-versioning)
8. [Version Update Script (`updateVersion.sh`)](#version-update-script)
9. [Output Structure & Tagging](#output-structure--tagging)
10. [Workflow Execution Summary](#workflow-execution-summary)
11. [Troubleshooting](#troubleshooting)
12. [FAQ](#faq)  

## Overview
This system standardises versioning across all repositories — Terraform modules, infrastructure code, shared libraries, and application repositories.

It automatically:

- Determines the next semantic version
- Updates `CHANGELOG.md`
- Updates the `version` file
- Creates an annotated Git tag `vX.Y.Z`
- Pushes the tag to the repository 

## Architecture Overview

```
┌────────────────────┐
│   Pull Request     │
│      (merged)      │
└─────────┬──────────┘
          │
          ▼
┌────────────────────────────────────────────────┐
│ Repo-level Workflow: repository-versioning.yml │
│ - Prints initial summary                       │
│ - Detects skip-ci                              │
│ - Calls composite action                       │
└─────────┬──────────────────────────────────────┘
          │ skip=false
          ▼
┌─────────────────────────────────────────────┐
│ Composite Action: repository-auto-versioning│
│ - Collects PR title/body/commits            │
│ - Determines current version                │
│ - Runs updateVersion.sh                     │
│ - Commits CHANGELOG + version               │
│ - Creates + pushes annotated tag            │
│ - Pushes release commit                     │
└─────────┬───────────────────────────────────┘
          │ new_version=X.Y.Z
          ▼
┌────────────────────────────────────────────┐
│ Repo Summary                               │
│ - Success/failure summary                  │
│ - Created tag displayed                    │
└────────────────────────────────────────────┘

```


## Semantic Versioning Rules

It follows below versioning pattern:

```
MAJOR.MINOR.PATCH
```

| Type of Change  |       Pattern        | Bump |
|-----------------|----------------------|------|
| Breaking Change | contains `BREAKING CHANGE` | **MAJOR** |
| Breaking Syntax | `feat!:`, `refactor!:`, `type!:` or ending with `!` | **MAJOR** |
| Feature | `feat:` or `feat(` | **MINOR** |
| Fix | `fix:` or `fix(` | **PATCH** |
| Default | none matched | **PATCH** |

## Precedence (important)

```
MAJOR > MINOR > PATCH
```

If ANY commit triggers MAJOR → MINOR/PATCH are ignored.

> **Notes:** Meaning, if any commit triggers MAJOR, MINOR/PATCH do not matter.



## Skip CI Detection (title, body, commits)

The workflow recognises below skip markers:

- `[skip ci]`
- `[skip-ci]`
- `skip_ci`
- `skip ci`

### Skip detection order:
1. PR title  
2. PR body  
3. PR commit messages  

If ANY of these contain skip-ci →  **versioning is skipped entirely**.

## Repo-Level Workflow (`repository-versioning.yml`)

This workflow must be placed in each repository that needs auto‑versioning.

It:
- Prints initial context
- Runs skip‑ci detection
- If not skipped → runs composite action (stored in sharedservice repository)
- Prints final summary


complete workflow: **repository-versioning.yml**

Example to use composite action in repo level workflow:

**Format**: uses: <owner>/<repo>[/<path-to-action>]@<ref> 

Example: 
1. if composite actions is shared from other git org/repo:

uses: my-org/shared-repo/.github/actions/repository-auto-versioning@v1.0.0  --> points to tag v1.0.0
uses: my-org/shared-repo/.github/actions/repository-auto-versioning@main    --> main branch

Example:

with branch name:

```
tool-ims/ims_tool-github-shared_actions/.github/actions/repository-auto-versioning@main
```
with version tag name:

```
tool-ims/ims_tool-github-shared_actions/.github/actions/repository-auto-versioning@v1.0.0
```
2. if composite action is in same repo as workflow

uses: ./.github/actions/repository-auto-versioning

```yml
name: Repository_versioning

on:
  pull_request:
    types: [closed]

permissions:
  contents: write
  pull-requests: read

jobs:
  tag-and-version:
    # Only run when the PR was merged
    if: ${{ github.event.pull_request.merged == true }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout (full)
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      # Initial Summary (ALWAYS RUNS)
      - name: Initial run summary
        id: initial_summary
        shell: bash
        run: |
          REPO="${{ github.repository }}"
          SERVER_URL="${{ github.server_url }}"
          RUN_ID="${{ github.run_id }}"
          RUN_NUMBER="${{ github.run_number }}"
          EVENT_NAME="${{ github.event_name }}"
          PR_NUMBER="${{ github.event.pull_request.number || '' }}"
          ACTOR="${{ github.actor }}"
          HEAD_REF="${{ github.head_ref || '' }}"
          BASE_REF="${{ github.base_ref || '' }}"
          {
            echo "## repository-auto-versioning — Initial Context"
            echo "- Repository: ${REPO}"
            echo "- Run: ${SERVER_URL}/${REPO}/actions/runs/${RUN_ID} (#${RUN_NUMBER})"
            echo "- Trigger: ${EVENT_NAME}"
            echo "- Actor: ${ACTOR}"
            if [ -n "${PR_NUMBER}" ] && [ "${PR_NUMBER}" != "null" ]; then
              echo "- PR: #${PR_NUMBER} (${HEAD_REF} → ${BASE_REF})"
            fi
            echo "- Next step: skip-ci detection"
          } >> "$GITHUB_STEP_SUMMARY"

      # Full "Skip CI" detection (title/body/commits)
      - name: Full Skip CI Check (title, body, commits)
        id: check_skip
        shell: bash
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          PR_NUMBER="${{ github.event.pull_request.number || '' }}"
          OWNER_REPO="${{ github.repository }}"
          echo "Checking PR #${PR_NUMBER} for skip markers (title / body / commits)..."

          contains_skip() {
            # Accept common variants: [skip ci], skip-ci, skip_ci, skip ci (case-insensitive)
            echo "$1" | grep -qiE '\[?skip[ _-]?ci\]?'
          }

          # default outputs so step always has outputs
          echo "skip=false" >> $GITHUB_OUTPUT
          echo "skip_where=none" >> $GITHUB_OUTPUT
          # Check PR title & body
          if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
            PR_TITLE=$(jq -r '.pull_request.title // ""' "${GITHUB_EVENT_PATH}" 2>/dev/null || echo "")
            PR_BODY=$(jq -r '.pull_request.body // ""' "${GITHUB_EVENT_PATH}" 2>/dev/null || echo "")
            echo "PR title: ${PR_TITLE}"
            echo "PR body: (length) $(printf "%s" "$PR_BODY" | wc -c) chars"

            if contains_skip "$PR_TITLE"; then
              echo "Found skip marker in PR title."
              echo "skip=true" >> $GITHUB_OUTPUT
              echo "skip_where=title" >> $GITHUB_OUTPUT
              exit 0
            fi

            if contains_skip "$PR_BODY"; then
              echo "Found skip marker in PR body."
              echo "skip=true" >> $GITHUB_OUTPUT
              echo "skip_where=body" >> $GITHUB_OUTPUT
              exit 0
            fi
          fi

          # Check each commit message in the PR using GitHub API
          echo "Fetching commits for PR via GitHub API..."
          commits_json=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/${OWNER_REPO}/pulls/${PR_NUMBER}/commits" || true)

          # If API returned JSON array, inspect commit messages; otherwise warn and skip commit-level checks.
          first_char="$(printf '%s' "$commits_json" | head -c 1 || echo '')"
          if [ "$first_char" = "[" ]; then
            printf '%s' "$commits_json" | jq -r '.[].commit.message' | while IFS= read -r msg; do
              if contains_skip "$msg"; then
                echo "Found skip marker in PR commit message"
                echo "skip=true" >> $GITHUB_OUTPUT
                echo "skip_where=commit" >> $GITHUB_OUTPUT
                exit 0
              fi
            done
          else
            echo "Warning: commits API returned non-array (or error). Skipping commit-level skip-ci detection."
            echo "commits_api_head: ${commits_json:0:200}"
          fi

      # Skip Notice (if skip ci=true)
      - name: Skip notice (when skip ci=true)
        if: ${{ steps.check_skip.outputs.skip == 'true' }}
        shell: bash
        run: |
          {
            echo "## repository-auto-versioning — Skipped"
            echo "- Reason: skip-ci marker detected"
            echo "- Location: ${{ steps.check_skip.outputs.skip_where }}"
            echo "- Composite action was not executed."
          } >> "$GITHUB_STEP_SUMMARY"

      # Configure Git for private modules
      - name: Configure Git for private modules
        if: ${{ steps.check_skip.outputs.skip == 'false' }}
        id: private_auth
        shell: bash
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          private_status="missing"
          if [ -n "${GITHUB_TOKEN:-}" ]; then
            # replace github.com with x-access-token URL so subsequent 'git' fetches can access private repos
            git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
            private_status="configured"
          fi
          echo "private_git_auth=${private_status}" >> $GITHUB_OUTPUT

      # Private auth summaries (success / failure)
      - name: Private auth success summary
        if: ${{ steps.check_skip.outputs.skip == 'false' && steps.private_auth.outcome == 'success' }}
        shell: bash
        run: |
          AUTH="${{ steps.private_auth.outputs.private_git_auth || 'unknown' }}"
          {
            echo "## repository-auto-versioning — Private Git config"
            echo "- Private module auth: ${AUTH}"
            echo "- Private auth step: succeeded"
          } >> "$GITHUB_STEP_SUMMARY"
      - name: Private auth failure summary
        if: ${{ steps.check_skip.outputs.skip == 'false' && steps.private_auth.outcome != 'success' }}
        shell: bash
        run: |
          AUTH="${{ steps.private_auth.outputs.private_git_auth || 'missing' }}"
          {
            echo "## repository-auto-versioning — Private Git config"
            echo "- Private module auth: ${AUTH}"
            echo "- Private auth step: FAILED"
            echo "- Note: Without configured private git auth, composite action may fail to fetch private modules or action code from other org repos."
            echo "- Tip: ensure the `GITHUB_TOKEN` or a PAT secret is available and the workflow has permission to use it."
          } >> "$GITHUB_STEP_SUMMARY"
      # 5) Pre-call composite summary
      - name: Pre-call summary for composite action repository-auto-version
        if: ${{ steps.check_skip.outputs.skip == 'false' && steps.private_auth.outcome == 'success' }}
        shell: bash
        run: |
          {
            echo "## repository-auto-versioning — Composite Start"
            echo "- Action: ./.github/actions/repository-auto-versioning"
            echo "- PR: #${{ github.event.pull_request.number }}"
            # try get current version from repo file if exists
            if [ -f version ]; then
              echo "- Current version (repo file): $(cat version | tr -d '\r\n')"
            else
              echo "- Current version: unknown (no version file)"
            fi
            echo "- Next: running composite action to compute new version"
          } >> "$GITHUB_STEP_SUMMARY"
      # Run composite repository-auto-versioning if NOT skipped and private_auth succeeded
      - name: Run repository-auto-versioning
        if: ${{ steps.check_skip.outputs.skip == 'false' && steps.private_auth.outcome == 'success' }}
        id: tagger
        uses:  ./.github/actions/repository-auto-versioning   # <- replace with your published composite action@tag
        with:
          pr_number: ${{ github.event.pull_request.number }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          upload_logs: 'false'

      # Repo-level result summary (on success of tagger)
      - name: Repo-level result summary (on success)
        if: ${{ steps.check_skip.outputs.skip == 'false' && steps.tagger.outcome == 'success' }}
        shell: bash
        run: |
          TAG="${{ steps.tagger.outputs.new_version || '' }}"
          {
            echo "## repository-auto-versioning — Result"
            echo "- Status: SUCCESS"
            if [ -n "${TAG}" ]; then
              echo "- Created tag: ${TAG}"
            else
              echo "- No tag created (unexpected). Check composite action logs."
            fi
            echo "- Composite action appended detailed summary."
            echo "- Tip: enable upload_logs: 'true' to capture /tmp/ci_versioning.log as an artifact for debugging."
          } >> "$GITHUB_STEP_SUMMARY"
      # Repo-level result summary (on failure of tagger)
      - name: Repo-level result summary (on failure)
        if: ${{ steps.check_skip.outputs.skip == 'false' && steps.tagger.outcome != 'success' }}
        shell: bash
        run: |
          {
            echo "## repository-auto-versioning — Result"
            echo "- Status: FAILED"
            echo "- The repository-auto-versioning composite action failed. See the composite step logs for details."
            echo "- Consider re-running with 'upload_logs: true' to capture debug artifact (/tmp/ci_versioning.log)."
          } >> "$GITHUB_STEP_SUMMARY"
```


## Composite Action (`repository-auto-versioning`)

`action.yml` stored inside:

```
tool-ims/ims_tool-github-shared_actions/.github/actions/repository-auto-versioning/action.yml
```

Its responsibilities:

- Checkout repo  
- Determine current version (tag > version file > default 0.0.0)  
- Collect all PR messages  
- Run version script  
- Commit changelog + version  
- Create & push annotated tag  
- Push commit to main branch  


complete **repository-auto-versioning.yml**

```yml
name: "repository-auto-versioning"
description: "Compute semver from PR commits, update CHANGELOG/version, create annotated tag vX.Y.Z and push."
author: "Tooling Team"

inputs:
  github_token:
    description: "GitHub token (optional). Defaults to secrets.GITHUB_TOKEN"
    required: false
  pr_number:
    description: "Pull Request number (required)."
    required: true
  upload_logs:
    description: "If 'true', upload detailed logs as an artifact for debugging (default false)."
    required: false
    default: "false"

outputs:
  new_version:
    description: "Annotated tag created (vX.Y.Z)"
    value: ${{ steps.release.outputs.new_version }}

runs:
  using: composite
  steps:
    - name: Checkout repository (target)
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Require PR number
      id: require_pr
      shell: bash
      run: |
        if [ -z "${{ inputs.pr_number }}" ] || [ "${{ inputs.pr_number }}" = "null" ]; then
          echo "Error: pr_number input is required for this action."
          exit 1
        fi
        echo "pr_number=${{ inputs.pr_number }}" >> $GITHUB_OUTPUT

    - name: Determine current version
      id: latest
      shell: bash
      run: |
        set -euo pipefail
        git fetch --tags --no-recurse-submodules || true
        latest_tag=""
        if git describe --tags --abbrev=0 >/dev/null 2>&1; then
          latest_tag=$(git describe --tags --abbrev=0)
          current="${latest_tag#v}"
        elif [ -f version ]; then
          current=$(cat version)
        else
          current="0.0.0"
        fi
        echo "latest_tag=${latest_tag:-}" >> $GITHUB_OUTPUT
        echo "current=${current}" >> $GITHUB_OUTPUT

    - name: Gather PR title/body and commit messages
      id: gather
      shell: bash
      env:
        GITHUB_TOKEN: ${{ inputs.github_token || secrets.GITHUB_TOKEN }}
      run: |
        set -euo pipefail
        PR="${{ inputs.pr_number }}"
        OUT="$(mktemp /tmp/commits.XXXXXX)"
        echo "PR_NUMBER=${PR}" > "${OUT}"
        echo "###COMMIT###" >> "${OUT}"

        if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
          PR_TITLE=$(jq -r '.pull_request.title // ""' "${GITHUB_EVENT_PATH}" 2>/dev/null || echo "")
          PR_BODY=$(jq -r '.pull_request.body // ""' "${GITHUB_EVENT_PATH}" 2>/dev/null || echo "")
          if [ -n "$PR_TITLE" ]; then
            echo "$PR_TITLE" >> "${OUT}"
            echo "###COMMIT###" >> "${OUT}"
          fi
          if [ -n "$PR_BODY" ]; then
            echo "$PR_BODY" >> "${OUT}"
            echo "###COMMIT###" >> "${OUT}"
          fi
        fi

        OWNER_REPO="${GITHUB_REPOSITORY}"
        commits_json=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          "https://api.github.com/repos/${OWNER_REPO}/pulls/${PR}/commits" || true)

        # write each commit.message to OUT
        echo "$commits_json" | jq -r '.[].commit.message' | while IFS= read -r msg; do
          [ -z "$msg" ] && continue
          echo "$msg" >> "${OUT}"
          echo "###COMMIT###" >> "${OUT}"
        done

        echo "commits_file=${OUT}" >> $GITHUB_OUTPUT

    - name: Initialize log file
      id: init_log
      shell: bash
      run: |
        LOG="/tmp/ci_versioning.log"
        echo "==== CI Versioning Log ====" > "${LOG}"
        echo "repo=${GITHUB_REPOSITORY}" >> "${LOG}"
        echo "pr=${{ inputs.pr_number }}" >> "${LOG}"
        echo "current=${{ steps.latest.outputs.current }}" >> "${LOG}"
        echo "commits_file=${{ steps.gather.outputs.commits_file }}" >> "${LOG}"
        echo "log_file=${LOG}" >> $GITHUB_OUTPUT

    - name: Run updateVersion script (bundled) with logging
      id: run_update
      shell: bash
      env:
        GITHUB_TOKEN: ${{ inputs.github_token || secrets.GITHUB_TOKEN }}
      run: |
        set -euo pipefail
        LOG="${{ steps.init_log.outputs.log_file }}"
        COMMITS_FILE="${{ steps.gather.outputs.commits_file }}"
        CURRENT="${{ steps.latest.outputs.current }}"
        SCRIPT="$GITHUB_ACTION_PATH/scripts/updateVersion.sh"

        if [ ! -f "$SCRIPT" ]; then
          echo "Error: bundled script not found at $SCRIPT" | tee -a "${LOG}" >&2
          exit 1
        fi
        chmod +x "$SCRIPT" || true

        echo "Running script: $SCRIPT $CURRENT $COMMITS_FILE" | tee -a "${LOG}"

        # Capture stdout of script separately and send stderr to log; diagnostics go to stderr in script,
        # final semver is printed to stdout by the script (guaranteed).
        STDOUT="$("$SCRIPT" "$CURRENT" "$COMMITS_FILE" 2>>"${LOG}")" || ( echo "updateVersion.sh failed; check ${LOG}" | tee -a "${LOG}" >&2; exit 1 )

        # Append stdout (should be just the semver line) to the log as well for traceability
        printf '%s\n' "${STDOUT}" >> "${LOG}"

        # Use last line of STDOUT as computed version (defensive)
        NEW="$(printf '%s\n' "${STDOUT}" | tail -n1 | tr -d '\r')"

        if [ -z "$NEW" ]; then
          echo "Failed to compute new version; check ${LOG}" | tee -a "${LOG}" >&2
          exit 1
        fi
        echo "computed_new_version=${NEW}" >> $GITHUB_OUTPUT

    - name: Commit CHANGELOG and version, create annotated tag
      id: release
      shell: bash
      env:
        GITHUB_TOKEN: ${{ inputs.github_token || secrets.GITHUB_TOKEN }}
      run: |
        set -euo pipefail
        LOG="${{ steps.init_log.outputs.log_file }}"
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.ghe.com"

        NEW="${{ steps.run_update.outputs.computed_new_version }}"
        TAG="v${NEW}"

        git add CHANGELOG.md version || true

        if git diff --cached --quiet; then
          echo "No changes to commit" | tee -a "${LOG}"
        else
          git commit -m "chore(release): ${TAG} [skip ci]" || echo "No commit created" | tee -a "${LOG}"
        fi

        git tag -a "${TAG}" -m "Version ${NEW}"
        if git push origin "${TAG}"; then
          echo "Pushed ${TAG}" | tee -a "${LOG}"
        else
          echo "Tag push failed; attempting retry with incremented patch" | tee -a "${LOG}"
          git fetch --tags --no-recurse-submodules || true
          latest_tag_now=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
          IFS='.' read -r ma mi pa <<< "${latest_tag_now#v}"
          pa=$((pa + 1))
          retry_tag="v${ma}.${mi}.${pa}"
          git tag -a "${retry_tag}" -m "Version ${retry_tag} (retry)"
          git push origin "${retry_tag}"
          TAG="${retry_tag}"
        fi

        # Push commit (may fail due to branch protection; that's expected in some orgs)
        git push origin HEAD:main || echo "Push of commit failed (permissions or branch protection)" | tee -a "${LOG}"

        echo "new_version=${TAG}" >> $GITHUB_OUTPUT

    - name: Upload logs (optional)
      if: ${{ inputs.upload_logs == 'true' }}
      uses: actions/upload-artifact@v4
      with:
        name: versioning-log-${{ inputs.pr_number }}-${{ steps.run_update.outputs.computed_new_version }}
        path: /tmp/ci_versioning.log
```

## Version Update Script

This script performs all semantic version evaluation, changelog generation and prints the final version to stdout.

It handles:

- MAJOR/MINOR/PATCH detection  
- Breaking change syntax  
- Skipping release commits  
- Updating changelog  
- Writing version file  
- Returning clean semantic version  

```bash
#!/usr/bin/env bash
set -euo pipefail

# This script is part of composite action repository-auto-versioning
# scripts/updateVersion.sh (centralized, verbose) 
# Usage: ./updateVersion.sh <current_version> <commits_file>
# - current_version: "X.Y.Z" or "vX.Y.Z"
# - commits_file: path containing PR title/body and commit messages separated by "###COMMIT###"
#
# Behavior:
# - Implements SemVer: MAJOR.MINOR.PATCH
# - BREAKING CHANGE or '!' -> MAJOR
# - feat: -> MINOR
# - fix: -> PATCH
# - Precedence: MAJOR > MINOR > PATCH
# - Prepends CHANGELOG.md with: "## vX.Y.Z" and list of commit subjects
# - Writes version file as X.Y.Z (no leading v)
# - Last stdout line = new version

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

  # Conventional '!' breaking (feat!:, refactor!:, etc)
  if printf '%s' "$subject" | grep -qE '^[a-zA-Z0-9]+(\([^)]+\))?!:|!$'; then
    bump_major=1
    printf '  -> \"!\" breaking change detected\n' >&2
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
  NEW_MAJ=$((CUR_MAJ + 1))
  NEW_MIN=0
  NEW_PAT=0
  printf 'Applying MAJOR bump\n' >&2
elif [ "$bump_minor" -eq 1 ]; then
  NEW_MAJ="$CUR_MAJ"
  NEW_MIN=$((CUR_MIN + 1))
  NEW_PAT=0
  printf 'Applying MINOR bump\n' >&2
elif [ "$bump_patch" -eq 1 ]; then
  NEW_MAJ="$CUR_MAJ"
  NEW_MIN="$CUR_MIN"
  NEW_PAT=$((CUR_PATCH + 1))
  printf 'Applying PATCH bump\n' >&2
else
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

# FINAL OUTPUT → machine-readable semantic version
printf '%s\n' "$NEW_VERSION"
```

## Output Structure & Tagging

Example:

```
Computed new_version=1.4.0
→ Writes version file: 1.4.0
→ Creates annotated tag: v1.4.0
→ Pushes commit: chore(release): v1.4.0 [skip ci]
→ Pushes tag: v1.4.0
```

## Workflow Execution Summary

On every merged PR, GitHub will show:

- Initial context summary  
- Skip-ci result  
- Composite action summary  
- Final result summary (tag shown)  


## Troubleshooting

### 1. Tag push fails?

Action retries with incremented patch tag.

### 2. Missing version?
Check:

```
/tmp/ci_versioning.log
```

### 3. Branch protection blocks commit?
Ensure bot has push permission.


## FAQ

### 1. Does this work for any repository?
Yes - Terraform, application, infra, tooling etc.

### 2. Do we require version starting with v?
Tag → starts with v  

version file contains:

```
X.Y.Z
```

### 3. Can I skip versioning?
Yes — add any of:

```
[skip ci]
[skip-ci]
skip_ci
skip ci
```
### 4. Does it work with existing tags?
Yes — automatically picks the latest semantic tag.