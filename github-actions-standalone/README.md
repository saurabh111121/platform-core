# GitHub Actions Standalone

This folder contains the complete GitHub Actions pipeline for teams that want to run CI/CD directly via GitHub Actions without Jenkins.

## Usage

Copy these workflows to `.github/workflows/`:

```bash
cp github-actions-standalone/*.yaml .github/workflows/
```

## Workflows

- `ci.yaml` — reusable build pipeline (test → build → push to ECR via OIDC)
- `deploy.yaml` — manual dispatch deploy to beta/gamma/prod via Kustomize
- `infra.yaml` — terraform plan → apply with environment approval gates
- `auto-destroy.yaml` — scheduled destroy of beta environment every 40 minutes

## Prerequisites

Set these in GitHub repo Settings → Variables:
- `AWS_ROLE_ARN` — IAM OIDC deployer role ARN
- `ECR_REGISTRY` — ECR registry URL

Per-environment variables:
- `EKS_CLUSTER_NAME` — EKS cluster name per environment
- `AWS_ROLE_ARN` — per-environment deployer role ARN
