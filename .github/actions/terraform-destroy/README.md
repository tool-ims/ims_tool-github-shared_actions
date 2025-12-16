# terraform-destroy (composite action)

Applies a **previously generated Terraform destroy plan** in a **deterministic, auditable, and production-safe** manner.

This action is designed to execute **only a reviewed destroy plan** produced by
`terraform-plan-destroy`. It intentionally avoids re-planning or implicit destroy
operations at execution time.

---

## What this action does

1. Consumes a Terraform **destroy plan file** (`.tfplan`)
2. Executes `terraform apply` using the **exact destroy plan**
3. Permanently removes infrastructure defined in the plan
4. Fails immediately on any error

> ⚠️ This action performs **destructive operations**.  
> It must always be protected by approval gates.

---

## Prerequisites

This action assumes the following have already been completed by the caller:

- Terraform CLI is installed
- `terraform init` has been executed
- Cloud credentials (e.g. AWS via OIDC) are configured
- A successful `terraform-plan-destroy` job has generated a destroy plan file
- Manual / environment-based approval has been enforced

---

## Inputs

| Name | Required | Default | Description |
|----|---------|---------|-------------|
| `working_directory` | Yes | `.` | Directory containing Terraform configuration (relative to repo root) |
| `plan_file` | Yes | — | Path to the Terraform destroy plan file (`.tfplan`) |

---

## Outputs

This action **does not produce outputs**.

Success or failure is determined solely by the Terraform apply execution.
---

## Usage example

```yaml
- name: Apply Terraform destroy plan
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-apply-destroy@main
  with:
    working_directory: terraform/network
    plan_file: destroy-plan-prd.tfplan
```

---

## Recommended workflow pattern

```
terraform-plan-destroy
        ↓
(manual / environment approval – REQUIRED)
        ↓
terraform-apply-destroy
```

This guarantees:
- Destroy intent is reviewed before execution
- No drift between plan and destroy
- Full auditability for destructive changes

---

## Design principles

- **Explicit destroy intent**
- **Apply only reviewed destroy plans**
- **No implicit re-planning**
- **Caller-owned configuration**
- **CI-safe, non-interactive execution**
- **Audit-friendly**

---

## What this action intentionally does NOT do

- Does not run `terraform destroy`
- Does not run `terraform plan`
- Does not run `terraform init`
- Does not compute backend configuration
- Does not read or infer tfvars
- Does not bypass approval gates

---

## Security notes (important)

- Always protect this action with **GitHub Environments** or equivalent approval mechanisms
- Never allow automatic destroy applies to production
- Review destroy plans carefully before approval
- Limit destroy permissions to dedicated IAM roles

---

## Typical pairing

This action is commonly used with:
- `terraform-plan-destroy`
- `print-run-context`
- `aws-auth-oidc`
- GitHub Environment–based approval gates