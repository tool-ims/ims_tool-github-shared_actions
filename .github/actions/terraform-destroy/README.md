## terraform-destroy (composite action)

Runs `terraform destroy` with the env-scoped var-file.

Inputs
- `working_directory` (string, default `.`): Terraform directory.
- `environment` (string, required): Env name (e.g., `sandbox`, `dev`).

Usage
```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-destroy@v1
  with:
    working_directory: example_deploy
    environment: sandbox
```

Notes
- Assumes Terraform and backend file exist (prefer running `terraform-setup` first).