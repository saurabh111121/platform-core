# Platform Core

An infrastructure-as-code platform for deploying containerized services on AWS EKS. It provides reusable Terraform modules, Kustomize-based Kubernetes manifests, and GitHub Actions CI/CD workflows across three environments (beta, gamma, prod).

## Architecture

```
                  ┌──────────────────────────────────────────────────┐
                  │                  GitHub Actions                  │
                  │  ci.yaml (reusable) → deploy.yaml → infra.yaml   │
                  └──────┬──────────────────┬──────────────┬─────────┘
                         │                  │              │
                    Build & Push      kubectl apply   terraform apply
                         │                  │              │
                  ┌──────▼──────┐   ┌───────▼──────┐  ┌────▼─────────────┐
                  │     ECR     │   │  EKS Cluster │  │  AWS Resources   │
                  │  (per-svc)  │──▶│  (Kustomize) │  │  VPC/IAM/EKS/ECR │
                  └─────────────┘   └──────────────┘  └──────────────────┘
```

Three layers work together:

1. **Terraform** provisions all AWS infrastructure (VPC, EKS, ECR, IAM)
2. **Kubernetes + Kustomize** defines application deployments with per-environment overlays
3. **GitHub Actions** automates building, pushing, deploying, and infrastructure changes

## Directory Structure

```
platform-core/
├── .github/
│   └── workflows/
│       ├── ci.yaml         # Reusable: test → build → push to ECR (OIDC)
│       ├── deploy.yaml     # Manual dispatch: kustomize → kubectl apply
│       └── infra.yaml      # Terraform plan → apply with env protection
├── config/
│   └── constants.yaml      # Central configuration — all tuneable values in one place
├── terraform/
│   ├── modules/
│   │   ├── vpc/            # VPC, subnets, NAT gateways, route tables
│   │   ├── eks/            # EKS cluster, managed node group, OIDC provider
│   │   ├── ecr/            # Container registries with lifecycle policies
│   │   └── iam/            # Cluster, node, and GitHub Actions deployer roles
│   └── environments/
│       ├── beta/           # t3.medium, 1–3 nodes, single NAT
│       ├── gamma/          # t3.large, 2–5 nodes, single NAT
│       └── prod/           # t3.xlarge, 3–10 nodes, HA NAT (3 gateways)
├── kubernetes/
│   ├── base/               # Deployment, Service, Ingress, HPA, ConfigMap
│   └── overlays/
│       ├── beta/           # 1 replica, debug logging, minimal resources
│       ├── gamma/          # 2 replicas, info logging
│       └── prod/           # 3 replicas, warn logging, 1 CPU / 1Gi limits
├── ci-cd/
│   └── .github/workflows/  # Reference copies of workflow sources
├── templates/
│   └── new-service/        # Starter template for onboarding new services
└── docs/
    ├── architecture.md     # Detailed architecture reference
    └── onboarding.md       # Step-by-step new service guide
```

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- `kubectl` and `kustomize`
- Docker
- Access to the GitHub org

## Quick Start

### 1. Provision Infrastructure

Each environment has its own Terraform root with an S3 backend:

```bash
cd terraform/environments/beta
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

This creates the VPC (3 public + 3 private subnets), EKS cluster, ECR repositories for the default services (`api`, `web`, `worker`), and all IAM roles.

### 2. Deploy a Service

```bash
# Configure kubectl
aws eks update-kubeconfig --name platform-core-beta --region us-west-2

# Build and push
IMAGE=<account>.dkr.ecr.us-west-2.amazonaws.com/beta/api:<tag>
docker build -t $IMAGE .
docker push $IMAGE

# Deploy to beta
cd kubernetes/overlays/beta
kustomize edit set image IMAGE_PLACEHOLDER=$IMAGE
kubectl apply -k .
```

### 3. Add a New Service

```bash
# Copy the template
cp -r templates/new-service/ ~/repos/my-service/

# Replace placeholders in all YAML files
find ~/repos/my-service -type f -name '*.yaml' | xargs sed -i 's/{{SERVICE_NAME}}/my-service/g'
find ~/repos/my-service -type f -name '*.yaml' | xargs sed -i 's|{{IMAGE}}|<account>.dkr.ecr.us-west-2.amazonaws.com/my-service:latest|g'

# Add the service name to terraform.tfvars in each environment
# services = ["api", "web", "worker", "my-service"]
```

See [docs/onboarding.md](docs/onboarding.md) for the full walkthrough.

## Infrastructure Details

### Terraform Modules

| Module | Resources | Key Config |
|--------|-----------|------------|
| **vpc** | VPC, 3 public + 3 private subnets, IGW, NAT gateway(s), route tables | `enable_ha_nat` for prod (3 NATs across AZs) |
| **eks** | EKS cluster (v1.29), managed node group, OIDC provider for IRSA | Instance types and scaling per environment |
| **ecr** | Per-service repositories, immutable tags, scan-on-push | Lifecycle: expire untagged after 7 days, keep last 20 tagged |
| **iam** | EKS cluster role, node role, GitHub Actions OIDC deployer role | Passwordless CI/CD via OIDC federation |

### Environment Sizing

| | Beta | Gamma | Prod |
|---|---|---|---|
| Instance type | t3.medium | t3.large | t3.xlarge |
| Node scaling | 1–3 | 2–5 | 3–10 |
| NAT gateways | 1 | 1 | 3 (HA) |
| K8s replicas | 1 | 2 | 3 |
| HPA range | 1–3 | 2–5 | 3–20 |
| CPU / Memory limits | 500m / 512Mi | 500m / 512Mi | 1000m / 1Gi |
| Log level | debug | info | warn |

### Kubernetes Manifests

The Kustomize base (`kubernetes/base/`) defines:

- **Deployment** — container with health probes (`/health`), resource requests/limits, configmap env injection
- **Service** — ClusterIP, port 80 → 8080
- **Ingress** — nginx ingress controller, path-based routing
- **HPA** — autoscaling at 70% CPU utilization
- **ConfigMap** — `LOG_LEVEL` and `PORT` settings

Environment overlays patch replica counts, HPA ranges, resource limits, and log levels.

## CI/CD Workflows

### ci.yaml — Build Pipeline (Reusable)

Triggered on push to `main`, PRs, or via `workflow_call` from service repos.

```yaml
# Service repos call it like this:
jobs:
  ci:
    uses: your-org/platform-core/.github/workflows/ci.yaml@main
    with:
      service_name: my-service
      dockerfile_path: ./Dockerfile
    secrets: inherit
```

Pipeline: **test → build → push to ECR** (push step only runs on `main` branch merges). Uses GitHub OIDC for AWS authentication — no static credentials.

### deploy.yaml — Deploy to Environment

Manual trigger (`workflow_dispatch`). Select the environment, service name, and image tag. Uses Kustomize to set the image and `kubectl apply` to deploy. Environment protection rules enforce approval gates for gamma and prod.

### infra.yaml — Infrastructure Changes

Triggered on push to `terraform/**` or manual dispatch. Runs `terraform plan`, uploads the plan as an artifact, then `terraform apply` in a separate job gated by environment protection rules.

## New Service Template

The `templates/new-service/` directory provides:

- **Dockerfile** — multi-stage Node.js build (build on `node:20-alpine`, run as non-root `appuser`)
- **Kubernetes manifests** — deployment with health probes, service, and per-environment Kustomize overlays
- **CI workflow** — calls the platform's reusable `ci.yaml` pipeline

Placeholders to replace: `{{SERVICE_NAME}}` and `{{IMAGE}}`.

## State Management

Terraform state is stored in S3 with per-environment keys:

| Environment | S3 Key |
|---|---|
| beta | `beta/terraform.tfstate` |
| gamma | `gamma/terraform.tfstate` |
| prod | `prod/terraform.tfstate` |

## Configuration

All tuneable values (AWS account ID, ECR registry, EKS cluster names, services list, environment sizing, container defaults, etc.) are centralized in [`config/constants.yaml`](config/constants.yaml). Update the `TODO` placeholders before deploying.

## Documentation

- [Architecture Overview](docs/architecture.md) — detailed infrastructure and application layer reference
- [Onboarding Guide](docs/onboarding.md) — step-by-step instructions for adding a new service
