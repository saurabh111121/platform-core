# Onboarding a New Service

## Prerequisites

- Access to the GitHub org and the `platform-core` repo
- AWS CLI configured with appropriate credentials
- `kubectl` and `kustomize` installed locally

## Steps

### 1. Copy the service template

```bash
cp -r platform-core/templates/new-service/ ~/repos/my-service/
```

### 2. Replace placeholders

In your copied files, replace all `{{SERVICE_NAME}}` and `{{IMAGE}}` placeholders:

```bash
# From your service repo root
find . -type f -name '*.yaml' -o -name '*.yml' | xargs sed -i 's/{{SERVICE_NAME}}/my-service/g'
find . -type f -name '*.yaml' -o -name '*.yml' | xargs sed -i 's|{{IMAGE}}|123456789012.dkr.ecr.us-west-2.amazonaws.com/my-service:latest|g'
```

Update the Kustomize overlay `namePrefix`, `commonLabels`, and image references to match your service.

### 3. Add service to Terraform

In `platform-core/terraform/terraform.tfvars`, add your service name to the services list:

```hcl
service_names = [
  "existing-service",
  "my-service"       # ← add here
]
```

This creates an ECR repository for your service. Run the `infra.yaml` workflow (or apply locally) to provision it.

### 4. Configure CI/CD secrets

In your service repo's GitHub settings (**Settings → Secrets and variables → Actions**), add:

| Secret | Value |
|--------|-------|
| `AWS_REGION` | e.g. `us-west-2` |
| `AWS_ACCOUNT_ID` | Your AWS account ID |
| `AWS_ROLE_ARN` | The `deployer_role_arn` output from the IAM module |

The deployer role uses GitHub OIDC — no static credentials needed.

### 5. Push and trigger pipelines

```bash
git add .
git commit -m "feat: add my-service with K8s manifests and CI"
git push origin main
```

On push to `main`:
1. **CI** runs automatically — tests, builds the Docker image, pushes to ECR
2. **Deploy** — trigger manually via `workflow_dispatch`, selecting the target environment (beta → gamma → prod)

### Verify

```bash
# Check pods
kubectl -n default get pods -l app=my-service

# Check service endpoint
kubectl -n default get svc my-service
```

## Environment Promotion

Deploy in order: **beta → gamma → prod**. Each environment uses GitHub environment protection rules for approval gates on gamma and prod.
