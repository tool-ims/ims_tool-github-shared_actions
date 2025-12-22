# GitHub App API Token (Internal)

Enterprise-approved GitHub composite action to generate a **short-lived
GitHub App installation token** for use in GitHub Actions workflows.

This action replaces third-party actions such as `tibdex/github-app-token`
and complies with restrictive enterprise Actions policies.

---

## Why This Action Exists

Many enterprises restrict GitHub Actions usage to:
- Organization-owned repositories
- GitHub-owned actions
- Approved internal actions

This action provides:
- A **secure, auditable** way to authenticate using a GitHub App
- **No PATs**
- **No OAuth user tokens**
- **No third-party dependencies**

---

## How It Works

1. Uses the GitHub App ID and private key to generate a JWT
2. Authenticates to the GitHub REST API as the App
3. Resolves the installation for the current organization
4. Exchanges the JWT for an installation access token
5. Exposes the token to subsequent workflow steps

The resulting token:
- Is scoped to the App installation
- Is valid for approximately **1 hour**
- Automatically expires

---

## Inputs

| Name | Required | Description |
|----|----|----|
| `app_id` | Yes | GitHub App ID |
| `private_key` | Yes | GitHub App private key (PEM format) |

---

## Outputs

| Name | Description |
|----|----|
| `token` | GitHub App installation access token |

---

## Usage Example

```yaml
- name: Generate GitHub App API token
  id: app-token
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/github-app-token@v1.0.0
  #uses: tool-ims/github-app-api-token/.github/actions/api-token@v1.0.0
  with:
    app_id: ${{ secrets.GH_APP_ID }}
    private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
```

## GitHub Enterprise Server Compatibility

This action uses github.api_url internally and works on:
- GitHub.com
- GitHub Enterprise Server (e.g. https://abc.ghe.com)

No configuration changes are required.