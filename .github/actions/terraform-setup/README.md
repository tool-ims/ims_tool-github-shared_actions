# terraform-setup (composite action)

Prepares a repository for Terraform execution in a **clean, minimal, and platform-aligned** way.

This action focuses only on **repository preparation and initialization**.  
It intentionally avoids installing Terraform, running security scanners, or inferring environment-specific configuration.

---

## What this action does

1. Configures Git to allow access to private Terraform modules
2. Runs `terraform fmt` in check mode
3. Runs `terraform init` (optionally with a backend config file)
4. Runs `terraform validate`

---

## What this action does NOT do

- Does **not** install Terraform (assumed to be available on the runner)
- Does **not** run security scanners (tfsec, checkov, etc.)
- Does **not** infer backend paths or environment layouts
- Does **not** run `terraform plan` or `terraform apply`
- Does **not** manage cloud authentication

---

## Prerequisites

The caller is responsible for ensuring:

- Terraform CLI is available on the GitHub runner
- Cloud authentication (e.g. AWS OIDC) is configured if required
- Backend configuration files (if used) already exist in the repo

---

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `working_directory` | No | `.` | Directory containing Terraform configuration |
| `backend_config_file` | No | `""` | Optional backend config file passed to `terraform init` |

---

## Outputs

This action does **not** expose outputs.

It fails the workflow if formatting, initialization, or validation fails.

---

## Usage examples

### Basic usage (local backend or inline backend)

```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-setup@main
  with:
    working_directory: terraform/network
```

---

### Usage with remote backend configuration

```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-setup@main
  with:
    working_directory: terraform/network
    backend_config_file: env/ppe/network.tfbackend
```

---

## Recommended workflow position

This action should be executed **before** any Terraform plan or apply step.

Typical placement:

```
print-run-context
        ↓
aws-auth-oidc
        ↓
terraform-setup
        ↓
terraform-plan
```

---

## Design principles

- **Single responsibility** – setup only
- **Caller-owned configuration**
- **Tool-agnostic** (no scanners, no cloud assumptions)
- **Fast and predictable**
- **Reusable across repositories**
