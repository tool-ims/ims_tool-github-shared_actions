## print-run-context (composite action)

Appends a human-readable context summary to the GitHub Step Summary: repo/run links, trigger, env, Terraform/Terratest metadata, and optional notes.

Inputs (commonly used)
- `title` (default: `Run Context`)
- `environment`, `aws_account_id`, `aws_role_arn`
- `working_directory`, `backend_config_file`, `var_file`, `plan_file`, `terraform_version`
- Terratest fields: `go_version`, `terratest_working_directory`, `terratest_pattern`, `terratest_timeout`
- `application`, `action_type`, `region` (default `eu-west-1`), `notes`

Usage
```yaml
- uses: tool-ims/ims_tool-github-shared_actions/.github/actions/print-run-context@v1
  with:
    title: Terraform Module Workflow Context
    environment: sandbox
    aws_account_id: ${{ vars.AWS_ACCOUNT_ID }}
    aws_role_arn: arn:aws:iam::${{ vars.AWS_ACCOUNT_ID }}:role/ims-terraform-infrastructure-role-sandbox
    working_directory: example_deploy
    terraform_version: 1.8.5
    application: example_deploy
    action_type: apply
```