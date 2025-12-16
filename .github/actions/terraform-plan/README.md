# terraform-plan (composite action)

Runs **`terraform plan`** in a consistent, CI-friendly way, captures both machine‑readable and human‑readable outputs, publishes a rich summary to the GitHub Actions UI, and uploads plan artifacts for downstream jobs (approval, apply, audit).

This action is **opinionated but flexible**:
- The **caller controls the var-file**
- The action handles **Terraform exit codes, outputs, summaries, and artifacts**
- No assumptions about repository layout beyond what the caller provides

---

## What this action does

1. Executes `terraform plan` with `-detailed-exitcode`
2. Interprets exit codes into workflow-friendly outputs
3. Saves the binary plan file (`.tfplan`)
4. Renders:
   - a human-readable plan (`plan.txt`)
   - a machine-readable plan (`plan.json`)
5. Publishes a collapsible plan summary to the **GitHub Actions Summary tab**
6. Uploads plan artifacts for later use (e.g. apply job)

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
| `plan_file` | Absolute path to the generated `.tfplan` file |
| `plan_text_path` | Absolute path to the rendered human-readable plan |
| `plan_json_path` | Absolute path to the rendered JSON plan |

These outputs are designed for **conditional logic** in workflows.

---

## Usage example

### Basic usage

```yaml
- id: plan
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-plan@main
  with:
    working_directory: terraform/network
    environment: ppe
    var_file: env/ppe/network.tfvars
```

---

### Conditional follow-up based on changes

```yaml
- name: Run terraform plan
  id: plan
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-plan@main
  with:
    working_directory: terraform/vpc
    environment: prd
    var_file: env/prd/vpc.tfvars

- name: No changes detected
  if: steps.plan.outputs.plan_status == 'no_changes'
  run: echo "Infrastructure is already up to date"

- name: Changes detected
  if: steps.plan.outputs.plan_status == 'changes'
  run: echo "Approval required before apply"
```

---

## Artifacts

This action uploads the following artifacts:

- Binary plan file: `plan-<environment>.tfplan`
- Human-readable plan: `plan.txt`
- JSON plan: `plan.json`

Artifact name:
```
tfplan-<environment>
```

These artifacts can be downloaded in later jobs or reused by a Terraform Apply action.

---

## GitHub Summary output

The action publishes a collapsible section to the **Actions → Summary** tab:

- Environment-scoped title
- Click-to-expand Terraform plan
- Clean, colorless output suitable for reviews and approvals

---

## Design principles

- Caller-owned configuration (no hardcoded repo layout)
- Correct handling of Terraform exit codes
- Machine + human outputs
- CI-safe, non-interactive execution
- Designed for reuse across repositories

---

## What this action intentionally does NOT do

- Does not run `terraform init`
- Does not configure cloud credentials
- Does not apply changes
- Does not assume backend or variable conventions

---

## Typical pairing

This action is commonly used with:
- A **Terraform setup/init** composite action
- A **print-run-context** action for platform context
- A **Terraform apply** action consuming the saved plan
- Policy-as-code checks (OPA / Conftest) against `plan.json`

---