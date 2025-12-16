# AWS OIDC Two-Hop Authentication (Composite Action)

## Overview

This composite GitHub Action provides a **standardized, secure, two-hop AWS authentication mechanism** using **GitHub Actions OIDC**.

It is designed for **multi-account AWS organizations**, where workflows must:

1. First assume an IAM role in the **organization / management account**
2. Then assume an IAM role with the **same name** in a **target (workload) account**

This action eliminates the need to duplicate authentication logic across workflows and enforces a **consistent, auditable IAM access pattern**.

---

## What This Action Does

This action performs the following steps:

1. Uses GitHub Actions OIDC to assume an IAM role in the **Org (management) account**
2. Uses the temporary credentials from step 1 to assume the IAM role in the **target AWS account**
3. Exposes AWS credentials for all subsequent steps in the job

After this action runs:
- AWS CLI
- Terraform
- SDKs (Go, Python, Node, etc.)

will all authenticate **against the target account**.

---

## Why Two-Hop Authentication Is Required

In many enterprise AWS setups:

- GitHub Actions is trusted **only by the Org account**
- Workload accounts do **not directly trust GitHub**
- Cross-account access is controlled centrally

This pattern provides:
- Centralized trust management
- Reduced blast radius
- Easier security audits
- Clear separation of responsibilities

---

## IAM Role Naming Convention

This action assumes the **same role name** exists in both accounts.

### Role naming pattern

`iamr-${var.tower}-${var.environment}-read`
`iamr-${var.tower}-${var.environment}-deploy`

### Example

iamr-cust-dev-deploy ----> for tower: cust, environment: dev

```
- In Org account: `arn:aws:iam::390403857119:role/iamr-cust-dev-deploy`
- In Target account(application account): `arn:aws:iam::424851482642:role/iamr-cust-dev-deploy'
```

- The role name is deterministic
- Only the **account ID changes** based on tower and environment name
- Makes automation predictable and auditable

## Basic usage in a workflow
```yml
- name: Authenticate to AWS (OIDC)
  uses: tool-ims/ims_tool-github-shared_actions/.github/actions/aws-oidc-auth@main
  with:
    target_account_id: ${{ steps.account.outputs.account_id }}
    tower: cust
    environment: dev
    region: eu-west-1
```