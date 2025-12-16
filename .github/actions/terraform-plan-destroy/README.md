# terraform-plan-destroy (composite action)

Runs **`terraform plan -destroy`** in a consistent, CI-friendly way, captures both machine-readable and human-readable outputs, publishes a rich summary to the GitHub Actions UI, and uploads destroy plan artifacts for downstream jobs (approval, review, audit).

This action is **opinionated but flexible**:
- The **caller controls the var-file**
- The action handles **Terraform exit codes, outputs, summaries, and artifacts**
- No assumptions about repository layout beyond what the caller provides

This action follows the **same contract and design pattern as `terraform-plan`**, with the only difference being the explicit **destroy intent**.

---

## What this action does

1. Executes `terraform plan -destroy` with `-detailed-exitcode`
2. Interprets Terraform exit codes into workflow-friendly outputs
3. Saves the binary destroy plan file (`.tfplan`)
4. Renders:
   - a human-readable destroy plan (`destroy-plan.txt`)
   - a machine-readable destroy plan (`destroy-plan.json`)
5. Publishes a collapsible destroy plan summary to the **GitHub Actions Summary tab**
6. Uploads destroy plan artifacts for later use (e.g. approval or destroy apply)

---

## Prerequisites

This action assumes the following have already been done by the caller:

- Terraform CLI is installed
- `terraform init` has been executed
- Cloud credentials (e.g. AWS) are configured

Typically, this action is used **after** a setup/init composite action.

---

## Inputs

| Name | Required | Default | Description |
|----|---------|---------|-------------|
| `working_directory` | Yes | `.` | Directory containing Terraform configuration (relative to repo root) |
| `environment` | Yes | — | Environment name (e.g. `dev`, `tst`, `ppe`, `prd`) |
| `var_file` | No | `""` | Path to a `.tfvars` file, relative to `working_directory` |

### Notes on `var_file`

- If provided, the action passes `-var-file=<path>` to Terraform
- If empty, **no var-file flag is added**
- The action does **not** derive or guess var-file paths

Examples:
```yaml
var_file: env/ppe/vpc.tfvars
```

```yaml
var_file: vars/common.tfvars
```

---

## Outputs

| Name | Description |
|----|-------------|
| `plan_status` | `changes` or `no_changes` (derived from `-detailed-exitcode`) |
| `plan_exit_code` | Raw Terraform exit code (`0` or `2`) |
| `plan_file` | Absolute path to the generated destroy `.tfplan` file |
| `plan_text_path` | Absolute path to the rendered human-readable destroy plan |
| `plan_json_path` | Absolute path to the rendered JSON destroy plan |

These outputs are designed for **conditional logic** and approval workflows.

---

## Usage example

### Basic usage

```yaml
- id: destroy_plan
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-plan-destroy@main
  with:
    working_directory: terraform/network
    environment: ppe
    var_file: env/ppe/network.tfvars
```

---

### Conditional follow-up based on changes

```yaml
- name: Run terraform destroy plan
  id: destroy_plan
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-plan-destroy@main
  with:
    working_directory: terraform/vpc
    environment: ppe
    var_file: env/ppe/vpc.tfvars

- name: No destroy changes detected
  if: steps.destroy_plan.outputs.plan_status == 'no_changes'
  run: echo "Nothing to destroy"

- name: Destroy changes detected
  if: steps.destroy_plan.outputs.plan_status == 'changes'
  run: echo "Explicit approval required before destroy"
```

---

## Artifacts

This action uploads the following artifacts:

- Binary destroy plan file: `destroy-plan-<environment>.tfplan`
- Human-readable destroy plan: `destroy-plan.txt`
- JSON destroy plan: `destroy-plan.json`

Artifact name:
```
tfdestroy-plan-<environment>
```

These artifacts can be downloaded in later jobs or reused by a Terraform Apply Destroy action.

---

## GitHub Summary output

The action publishes a collapsible section to the **Actions → Summary** tab:

- Environment-scoped title
- Click-to-expand destroy plan
- Clean, colorless output suitable for reviews and approvals

---

## Design principles

- Same contract as `terraform-plan`
- Caller-owned configuration (no hardcoded repo layout)
- Correct handling of Terraform destroy exit codes
- Machine + human outputs
- CI-safe, non-interactive execution
- Explicit and auditable destroy intent

---

## What this action intentionally does NOT do

- Does not run `terraform init`
- Does not configure cloud credentials
- Does not apply destroy changes
- Does not assume backend or variable conventions

---

## Typical pairing

This action is commonly used with:
- A **Terraform setup/init** composite action
- A **print-run-context** action for platform context
- A **Terraform apply-destroy** action consuming the saved destroy plan
- Approval gates for destructive operations
- Policy-as-code checks (OPA / Conftest) against `destroy-plan.json`

---