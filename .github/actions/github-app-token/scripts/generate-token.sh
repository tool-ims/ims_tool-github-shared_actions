#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Ensure jq is available (install if missing)
# -------------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Attempting to install..."

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y jq
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y jq
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y && sudo apt-get install -y jq
  else
    echo "ERROR: No supported package manager found to install jq"
    exit 1
  fi
fi
# -------------------------------------------------------------------
# Ensure openssl exists
# -------------------------------------------------------------------
command -v openssl >/dev/null 2>&1 || { echo "openssl is required"; exit 1; }

# -------------------------------------------------------------------
# Validate required inputs
# -------------------------------------------------------------------
if [[ -z "${APP_ID:-}" || -z "${PRIVATE_KEY:-}" ]]; then
  echo "APP_ID and PRIVATE_KEY must be set"
  exit 1
fi

# -------------------------------------------------------------------
# Create JWT for GitHub App authentication
# -------------------------------------------------------------------
now=$(date +%s)
iat=$((now - 60))
exp=$((now + 600)) # JWT valid for 10 minutes

header='{"alg":"RS256","typ":"JWT"}'
payload=$(jq -n \
  --arg iat "$iat" \
  --arg exp "$exp" \
  --arg iss "$APP_ID" \
  '{iat: ($iat|tonumber), exp: ($exp|tonumber), iss: ($iss|tonumber)}')

b64() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

unsigned="$(printf '%s' "$header" | b64).$(printf '%s' "$payload" | b64)"

signature=$(printf '%s' "$unsigned" \
  | openssl dgst -sha256 -sign <(printf '%s\n' "$PRIVATE_KEY") \
  | b64)

jwt="${unsigned}.${signature}"

# -------------------------------------------------------------------
# Resolve installation ID for the current org
# -------------------------------------------------------------------
installations=$(curl -s \
  -H "Authorization: Bearer ${jwt}" \
  -H "Accept: application/vnd.github+json" \
  "${GITHUB_API_URL}/app/installations")

installation_id=$(printf '%s' "$installations" | jq -r '.[0].id')

if [[ -z "$installation_id" || "$installation_id" == "null" ]]; then
  echo "ERROR: GitHub App is not installed on this organization"
  exit 1
fi

# -------------------------------------------------------------------
# Exchange JWT for installation access token
# -------------------------------------------------------------------
token=$(curl -s -X POST \
  -H "Authorization: Bearer ${jwt}" \
  -H "Accept: application/vnd.github+json" \
  "${GITHUB_API_URL}/app/installations/${installation_id}/access_tokens" \
  | jq -r '.token')

if [[ -z "$token" || "$token" == "null" ]]; then
  echo "ERROR: Failed to retrieve installation token"
  exit 1
fi

echo "token=${token}" >> "$GITHUB_OUTPUT"