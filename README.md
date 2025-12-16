# Platform GitHub Composite Actions

This repository contains **production-grade GitHub composite actions** used to standardise
**Terraform infrastructure workflows**, **application pipelines**, and **repository governance** across the organisation.

The actions are designed around **clear responsibility boundaries**, **deterministic execution**,
and **enterprise-safe approval and versioning patterns**.

---

## Table of Contents

This Table of Contents reflects the public contract of the platform actions.

1. [Design Principles](#design-principles)
2. [Action Catalog](#action-catalog)
   - [print-run-context](#print-run-context)
   - [aws-auth-oidc](#aws-auth-oidc)
   - [terraform-setup](#terraform-setup)
   - [terraform-plan](#terraform-plan)
   - [terraform-plan-destroy](#terraform-plan-destroy)
   - [terraform-apply](#terraform-apply)
   - [terraform-apply-destroy](#terraform-apply-destroy)
   - [repository-auto-versioning](#repository-auto-versioning)
3. [Recommended Workflow Patterns](#recommended-workflow-patterns)
4. [Security Posture](#security-posture)
5. [How to Consume These Actions](#how-to-consume-these-actions)
6. [Versioning & Governance](#versioning--governance)
7. [Repository Structure](#repository-structure)
8. [Ownership](#ownership)

---

## Design Principles

All actions in this repository follow these principles:

- **Single responsibility** per action
- **Caller-owned configuration**
- **Deterministic execution** (plan → apply symmetry)
- **Approval only for state-changing operations**
- **Tool-agnostic and reusable**
- **Repository versioning treated as governance, not pipelines**
- **No long-lived secrets**
- **Audit-friendly by default**

---

## Action Catalog

### print-run-context

**Purpose:**  
Prints a human-readable summary of workflow inputs and GitHub execution context
to the GitHub Step Summary.

**Typical usage:**  
First step in *every* workflow (infra, app, scan, deploy, versioning).

---

### aws-auth-oidc

**Purpose:**  
Authenticates GitHub Actions to AWS using **OIDC** (no static credentials).

**Typical usage:**  
Before any Terraform or AWS-dependent step.

---

### terraform-setup

**Purpose:**  
Prepares a repository for Terraform execution.

**Responsibilities:**
- Git configuration for private modules
- `terraform fmt`
- `terraform init`
- `terraform validate`

---

### terraform-plan

**Purpose:**  
Generates a Terraform plan and publishes artifacts and summaries.

---

### terraform-plan-destroy

**Purpose:**  
Generates an explicit Terraform **destroy plan**.

---

### terraform-apply

**Purpose:**  
Applies a **previously reviewed Terraform plan**.

---

### terraform-apply-destroy

**Purpose:**  
Applies a **previously reviewed Terraform destroy plan**.

---

### repository-auto-versioning

**Purpose:**  
Provides a reusable composite action for **automated semantic versioning**, **CHANGELOG generation**, and **annotated Git tag creation** on every Pull Request.

**Important distinction:**  
This is a **repository-governance composite action**.  
It is **not executed inside CI/CD pipelines** such as build, scan, deploy, or Terraform workflows.

**What it does:**
- Determines current version (Git tag → `version` file → `0.0.0`)
- Collects PR title, PR body, and commit messages
- Applies strict semantic versioning rules
- Updates `CHANGELOG.md` and `version`
- Creates and pushes annotated Git tags (`vX.Y.Z`)
- Supports full `skip-ci` detection

**What it does NOT do:**
- Does not deploy code
- Does not run Terraform
- Does not participate in pipelines

**Execution model:**
- Triggered by a **repo-level workflow** (typically on PR merge)
- Runs independently of CI/CD pipelines
- Governs repository version state only

**Location:**
```
.github/actions/repository-auto-versioning/
```

---

## Recommended Workflow Patterns

### Infrastructure: Plan → Approve → Apply

```
print-run-context
        ↓
aws-auth-oidc
        ↓
terraform-setup
        ↓
terraform-plan
        ↓
(terraform-apply job with mandatory environment approval)
```

---

### Infrastructure Destroy (Strict)
```
print-run-context
        ↓
aws-auth-oidc
        ↓
terraform-setup
        ↓
terraform-plan-destroy
        ↓
(terraform-apply-destroy job with mandatory approval)
```

---

### Repository Versioning (Repo-Level Governance)

This workflow runs **outside of all CI/CD pipelines**.

Trigger:
- Pull Request merged into default branch

Flow:
```
print-run-context
        ↓
skip-ci detection
        ↓
repository-auto-versioning
        ↓
annotated tag vX.Y.Z created
```

---

## Security Posture

### Authentication
- Uses **OIDC** for AWS authentication
- GitHub token scoped to repo where required
- No long-lived secrets or access keys
- IAM roles enforce least privilege

### Approvals
- Approvals required only for **state-changing operations**
  - Terraform apply
  - Terraform apply destroy
  - Production deployments
- Not required for:
  - Plans
  - Scans
  - Version computation
- GitHub Environments are the preferred approval mechanism

### Blast Radius Control
- Plan/apply separation prevents unintended changes
- Destroy operations require explicit plans and approvals
- Artifacts preserved for audit and rollback analysis

---

## How to Consume These Actions

1. Reference the action using:
   ```
   uses: <org>/<repo>/.github/actions/<action-name>@v1
   ```
2. Start workflows with `print-run-context`
3. Authenticate early using `aws-auth-oidc`
4. Use `terraform-setup` once per job
5. Always separate plan and apply into different jobs
6. Protect apply jobs with environment approvals

See the `examples/` directory for ready-to-use workflows.

---

## Versioning & Governance

- All composite actions follow **semantic versioning**
- Breaking changes increment major versions
- Repository versioning is PR-driven and auditable

---

## Repository Structure

```
.github/actions/
  print-run-context/
  aws-auth-oidc/
  terraform-setup/
  terraform-plan/
  terraform-plan-destroy/
  terraform-apply/
  terraform-apply-destroy/
  repository-auto-versioning/

README.md
CHANGELOG.md
version
```

---

## Ownership

Maintained by the **Platform / Terraform Tooling Team**.
