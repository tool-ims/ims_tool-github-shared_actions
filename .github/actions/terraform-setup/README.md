# terraform-setup (composite action)

Prepares a Terraform working directory:
- Renders backend config from `env/tfbackend.template` to `env/<env>/<env>.tfbackend`.
- Installs Terraform.
- Runs `terraform fmt -check`, `terraform init` (with rendered backend), and `terraform validate`.
- Runs `tfsec` (soft-fail by default) for security scanning.

Inputs
- `terraform_version` (string, optional): Terraform CLI version. Default `1.8.5`.
- `environment` (string, required): Environment name used to render backend (e.g., `sandbox`, `dev`).
- `working_directory` (string, optional): Terraform module directory. Default `.`.

Usage
```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-setup@v1
  with:
    environment: sandbox
    working_directory: example_deploy
    terraform_version: 1.8.5
```

Notes
- Expects a template at `env/tfbackend.template` in `working_directory`.
- Exports `${environment}` for template expansion.