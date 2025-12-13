## terraform-plan-destroy (composite action)

Runs `terraform plan -destroy` with env-scoped var-file and publishes artifacts + a summary.

Inputs
- `working_directory` (string, default `.`): Terraform directory.
- `environment` (string, required): Env name (e.g., `sandbox`, `dev`) used to select `env/<env>/<env>.tfvars`.

Outputs
- `plan_status`: `changes` or `no_changes`.
- `plan_exit_code`: `0` or `2`.
- `plan_file`: Absolute path to the destroy `.tfplan`.
- `plan_text_path`: Path to human-readable plan.
- `plan_json_path`: Path to JSON plan.

Usage
```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/terraform-plan-destroy@v1
  with:
    working_directory: example_deploy
    environment: sandbox
```

Notes
- Assumes Terraform has been installed and init run (use `terraform-setup` beforehand).