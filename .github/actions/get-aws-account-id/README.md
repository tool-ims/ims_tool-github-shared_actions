# get-aws-account-id (Composite Action)

A **platform-standard GitHub composite action** that resolves an **AWS Account ID** based on **workload tower (OU)** and **environment**, using a centrally managed mapping file.

This action is designed for **enterprise Terraform and application workflows** where account resolution must be **deterministic, auditable, and policy-driven**.

---

## Overview

`get-aws-account-id`:

- Resolves AWS account IDs from a **single source of truth**
- Enforces **strict validation**
- Fails fast on invalid or missing mappings
- Produces a clean output for downstream actions (OIDC, Terraform, deploy)

This action **does not authenticate to AWS**.
It only resolves the **target account ID**.

---
## Repository Layout

```
.github/actions/get-aws-account-id/
├── action.yml
├── scripts/
│   └── get_account_id.py
├── mappings/
│   └── aws-accounts-mapping.json
└── README.md
```

## Why This Action Exists

In large organisations:

- Account IDs **must not** be hardcoded in workflows
- Account selection must be **consistent across repos**
- Mapping logic must be **centralised and reviewable**
- Pipelines must fail **early and clearly** when configuration is invalid

This action enforces all of the above.

---

## Inputs

| Input        | Required | Description                                  |
|--------------|----------|----------------------------------------------|
| `tower`      |  Yes   | Workload tower / OU name (e.g. `tu`, `int`, `cust`, `sec`, `coll`, `comm`, `fin` ) |
| `environment`|  Yes   | Environment (`dev`, `tst`, `ppe`, `prd`)     |

---

## Outputs

| Output       | Description                 |
|--------------|-----------------------------|
| `account_id` | Resolved AWS Account ID     |

---

## Usage Example

### Basic Usage

```yml
- name: Fetch AWS account ID
  id: account
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/fetch-aws-account-id@main  # tag like v1.0.0
  with:
    tower: cust
    environment: prd

- name: Use account ID
  run: echo "Target AWS Account: ${{ steps.account.outputs.account_id }}"
```

### With AWS OIDC Authentication

```yml
- name: Fetch AWS account ID
  id: account
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/fetch-aws-account-id@main  # tag like v1.0.0
  with:
    tower: cust
    environment: prd
 
- name: AWS authentication (OIDC)
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/aws-auth-oidc@main
  with:
    target_account_id: ${{ steps.account.outputs.account_id }}
    tower: ${{ inputs.workload_tower }}
    environment: ${{ inputs.environment }}
    region: ${{ inputs.region }}
 ```

 ## Mapping File Structure
The action uses a centrally managed mapping file located at:
```
mappings/aws-accounts-mapping.json
```

### Example
```json
{
  "cust": {
    "dev":  { "account_id": "111111111111" },
    "tst":  { "account_id": "222222222222" },
    "ppe":  { "account_id": "333333333333" },
    "prd":  { "account_id": "444444444444" }
  },
  "fin": {
    "dev":  { "account_id": "555555555555" },
    "prd":  { "account_id": "666666666666" }
  }
}
```
### Validation Rules
- Each `tower` must map to one or more environments.
- tower must exist as a top-level key
- account_id must be non-empty
- Missing or invalid mappings cause a **hard failure**
## Security & Governance

-   No AWS credentials required
-   No secrets consumed
-   Mapping changes are fully auditable via Git history
-   Designed for OIDC-based, least-privilege workflows