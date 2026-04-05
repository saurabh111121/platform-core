# Config

`constants.yaml` is the central reference for all configurable values in this platform.

Before deploying, update the `TODO` items:
- `aws_account_id` — your real AWS account ID
- `ecr_registry` — derived from account ID and region
- `deployer_role_arn` — the IAM OIDC role ARN from the `iam` Terraform module output
- `terraform_state_bucket` — your S3 bucket for Terraform state

These values are referenced across GitHub Actions workflows, Kubernetes manifests, and Terraform configs.
