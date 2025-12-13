# GitHub Composite Actions

Reusable GitHub composite actions maintained by the Tooling team to standardise Terraform workflows across repositories.

---

## Table of Contents

- [Composite Actions](#composite-actions)
  - [terraform-setup](#githubactionsterraform-setup)
  - [print-run-context](#githubactionsprint-run-context)
  - [terraform-plan](#githubactionsterraform-plan)
  - [terraform-plan-destroy](#githubactionsterraform-plan-destroy)
  - [terraform-apply](#githubactionsterraform-apply)
  - [terraform-destroy](#githubactionsterraform-destroy)
  - [repository-auto-versioning](#githubactionsrepository-auto-versioning)
- [Reusable Workflows](#reusable-workflows)
- [Requirements](#requirements)
- [Versioning](#versioning)

---

## Composite Actions

### `.github/actions/terraform-setup`

Bootstrap Terraform repositories: configure private module access, install Terraform, run `fmt` / `validate`, and run `tfsec` (always on).

```yaml
- uses: actions/checkout@v4
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-setup@main
  with:
    terraform_version: 1.8.5 # optional; defaults to 1.8.5
```

Notes:
- Runs in the job's working directory. Set `defaults.run.working-directory` in your workflow or add `working-directory` on the step to target a module folder.

Docs:
- For detailed behavior and examples, see [terraform setup README](.github/actions/terraform-setup/README.md)

### `.github/actions/print-run-context`
Append a human‑readable summary (title, repo/run links, env, Terraform/Terratest metadata) to the job summary.

- Inputs: `title`, `environment`, `aws_account_id`, `aws_role_arn`, `working_directory`, `backend_config_file`, `var_file`, `plan_file`, `terraform_version`, `go_version`, `terratest_*`, `notes`
- Example:
```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/print-run-context@main
  with:
    title: Terraform Module Workflow Context
    environment: sandbox
    aws_account_id: ${{ vars.AWS_ACCOUNT_ID }}
    working_directory: infra
    plan_file: plan-sandbox.tfplan
    terraform_version: 1.8.5
```
Docs:
- For detailed behavior and examples, see [print run context README](.github/actions/print-run-context/README.md)

### `.github/actions/terraform-plan`
Run terraform plan for a given environment and upload plan artifacts for cross-job reuse.

```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-plan@main
  with:
    environment: sandbox
```
Note: Ensure Terraform is installed first (use `terraform-setup`).

Docs:
- For detailed behavior and examples, see [terraform plan README](.github/actions/terraform-plan/README.md)

### `.github/actions/terraform-plan-destroy`
Run terraform plan -destroy for a given environment and upload plan artifacts for cross-job reuse.

```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-plan-destroy@main
  with:
    environment: sandbox
```
Note: Ensure Terraform is installed first (use `terraform-setup`).

Docs:
- For detailed behavior and examples, see [terraform plan destroy README](.github/actions/terraform-plan-destroy/README.md)

### `.github/actions/terraform-apply`
Apply the configuration for a given environment (file-driven backend + tfvars). Assumes `terraform-setup` has run.

```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-apply@main
  with:
    environment: sandbox
```
Note: Ensure Terraform is installed first (use `terraform-setup`).

Docs:
- For detailed behavior and examples, see [terraform apply README](.github/actions/terraform-apply/README.md)

### `.github/actions/terraform-destroy`
Destroy the configuration for a given environment (file-driven backend + tfvars). Assumes `terraform-setup` has run.

```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-destroy@main
  with:
    environment: sandbox
```

Docs:
- For detailed behavior and examples, see [terraform destroy README](.github/actions/terraform-destroy/README.md)

### `.github/actions/repository-auto-versioning`

Automatically manages semantic versioning for repositories when a Pull Request is merged.
This action:
	•	Determines the next version based on PR labels / commit semantics
	•	Updates the version file (e.g. VERSION)
	•	Updates CHANGELOG.md
	•	Creates and pushes an annotated Git tag (e.g. v1.4.0)
	•	Optionally uploads execution logs as artifacts

Designed to be reusable across Terraform modules, application repos, and infra repositories.

```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/repository-auto-versioning@main
  with:
    pr_number: ${{ github.event.pull_request.number }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

- Inputs
	-	`pr_number` – Pull Request number used to determine version bump and changelog entries
	-	`github_token` – GitHub token with permission to create commits and tags

- Outputs
	-	`new_version` – The newly calculated semantic version (e.g. 1.3.2)
	-	`tag` – The Git tag created (e.g. v1.3.2)
	-	`release_type` – Version bump type (major | minor | patch)

- Notes
	-	Should be executed only after PR merge
	-	Requires contents: write permission
	-	Assumes the repository follows semantic versioning
	-	Works best when PRs are labeled (major, minor, patch) or follow conventional commits

- Docs:
  For detailed behavior and examples, see [terraform repository versioning README](.github/actions/repository-auto-versioning/README.md)

## Reusable Workflows

### `.github/workflows/terraform-module.yml`
Single reusable workflow for `plan`, `apply`, and `destroy` (via `action` input`). Uses `<env>-deploy` for approval gates and `<env>` for execution. Apply/Destroy are gated on all branches.

- Inputs: `working_directory`, `environment`, `action` (plan|apply|destroy)
- Behavior:
  - plan: setup → plan (artifacts + summary)
  - apply: setup → plan → approval in `<env>-deploy` → setup → apply
  - destroy: setup → plan-destroy (artifacts + summary) → approval in `<env>-deploy` → setup → destroy
- Example:
```yaml
jobs:
  module:
    uses: tool-ims/ims_tool-github-shared_actions/.github/workflows/terraform-module.yml@main
    with:
      working_directory: infra
      environment: sandbox
      action: apply
    secrets: inherit
```

## Requirements

- Org settings: allow reuse of workflows from private repositories (for cross‑repo reuse)
- Repo vars: `AWS_ACCOUNT_ID` (or equivalent)
- Environments:
  - `<env>` (e.g. `sandbox`) — unprotected; holds env‑scoped vars/secrets; used by plan/apply/destroy
  - `<env>-deploy` — protected; Required reviewers or Wait timer; used only for approval gates
- IAM OIDC trust: allow `repo:<org>/<repo>:environment:<env>` in the role trust policy

## Versioning

Use `@v1` for stable major, or `@main` while iterating.