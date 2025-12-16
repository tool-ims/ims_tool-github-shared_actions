# terraform-apply (composite action)

Applies a **previously generated Terraform plan** in a **deterministic, auditable, and production-safe** manner.

This action is designed to work **only with a saved plan file** produced by `terraform-plan`.  
It intentionally avoids re-planning, backend reconfiguration, or tfvars evaluation during apply.

---

## What this action does

1. Consumes a Terraform plan file (`.tfplan`)
2. Executes `terraform apply` using the **exact reviewed plan**
3. Applies infrastructure changes deterministically
4. Fails immediately on any error

---

## Prerequisites

This action assumes the following have already been completed by the caller:

- Terraform CLI is installed
- `terraform init` has been executed
- Cloud credentials (e.g. AWS via OIDC) are configured
- A successful `terraform-plan` job has generated a plan file
- Any required approval gates have been satisfied

---

## Inputs

| Name | Required | Default | Description |
|----|---------|---------|-------------|
| `working_directory` | Yes | `.` | Directory containing Terraform configuration (relative to repo root) |
| `plan_file` | Yes | — | Path to the Terraform plan file (`.tfplan`) |

---

## Outputs

This action **does not produce outputs**.

Success or failure is determined entirely by the Terraform apply execution.

---

## Usage example

```yaml
- name: Terraform apply
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-apply@main
  with:
    working_directory: terraform/network
    plan_file: plan-prd.tfplan
```

---

## Recommended workflow pattern

```
terraform-plan
        ↓
(manual / environment approval)
        ↓
terraform-apply
```

This guarantees:
- The reviewed plan is the applied plan
- No drift between plan and apply
- Full auditability

---

## Design principles

- **Apply only reviewed plans**
- **No implicit re-planning**
- **Caller-owned configuration**
- **CI-safe, non-interactive execution**
- **Deterministic behavior**

---

## What this action intentionally does NOT do

- Does not run `terraform plan`
- Does not run `terraform init`
- Does not compute backend configuration
- Does not read or infer tfvars
- Does not bypass approval gates

---

## Security notes

- Always protect apply jobs with **GitHub Environments** or equivalent approval gates
- Secrets are injected only after approval when using environments
- Never auto-apply directly from feature branches to production

---

## Typical pairing

This action is commonly used with:
- `terraform-plan`
- `print-run-context`
- `aws-auth-oidc`
- GitHub Environment–based approvals
