# print-run-context (composite action)

Appends a **human-readable, platform-standard run context summary** to the **GitHub Actions Job Summary**.

This action is **tool-agnostic** and intended to provide clear, consistent context for **any workflow type** (Terraform, application build, scan, upload, bootstrap, etc.) without leaking tool or account details.

---

## What this action does

The summary includes:

- Repository and workflow name
- Run link and run number
- Trigger type (push, PR, workflow_dispatch, etc.)
- Actor and triggering actor
- Git ref
- Pull request details (if applicable)
- **Platform context** (tower, environment, sub-environment, region)
- **Workload context** (application, action, working directory)

All fields are **conditionally rendered**:
- If a value is not provided, it is **not printed**
- No placeholder values like `n/a`
- Repository root is implicit if `working_directory` is empty

---

## Inputs

| Name | Required | Default | Description |
|----|---------|---------|-------------|
| `title` | No | `Run Context` | Title for the summary section |
| `workload_tower` | No | `""` | Workload tower (`tu`, `int`, `cust`, `sec`, `coll`, `comm`, `fin`) |
| `environment` | No | `""` | Primary environment (`dev`, `tst`, `ppe`, `prd`) |
| `sub_environment` | No | `""` | Encoded sub-environment (see rules below) |
| `application` | No | `""` | Application, service, or module name |
| `action` | No | `""` | High-level intent of the workflow run |
| `region` | No | `""` | Execution or deployment region |
| `working_directory` | No | `""` | Working directory relative to repo root (empty = root) |

---

## Outputs

This action **does not produce outputs**.

It writes a formatted Markdown summary to the GitHub-provided environment variable:

- `GITHUB_STEP_SUMMARY`

---

## Sub-environment rules

`sub_environment` is **optional**, but **cannot exist without `environment`**.

Valid combinations:

| Environment | Allowed `sub_environment` |
|------------|---------------------------|
| `prd` | `prb`, `prg` |
| `ppe` | `ppb`, `ppg` |
| `tst` | `sta`, `stb` |
| `dev` | Any or none |

Invalid combinations will fail the workflow early with a clear error.

---

## Action field (important)

The `action` input represents the **intent of the workflow**, not the tool implementation.

Examples:

- `bootstrap`
- `terraform-plan`
- `terraform-apply`
- `terraform-destroy`
- `app-build`
- `image-scan`
- `artifact-upload`

This keeps the action **tool-independent** while still being expressive.

---

## Usage example

```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/print-run-context@main
  with:
    title: Terraform Module Workflow Context
    workload_tower: fin
    environment: prd
    sub_environment: prb
    application: payments-api
    action: terraform-apply
    region: eu-west-1
    working_directory: terraform/payments
```

---

## Design principles

- Tool-agnostic (no Terraform, Go, AWS, or test knowledge)
- Platform vocabulary only
- Conditional, noise-free output
- Safe for audits and reviews
- Suitable for org-wide standardisation

---

## What this action intentionally does **not** do

- Does not assume cloud provider or account details
- Does not print Terraform / build / scan metadata
- Does not auto-derive environments or stages
- Does not modify workflow execution
