# Architecture Overview

## Overview

This platform uses **Terraform** for infrastructure provisioning, **Kubernetes with Kustomize** for application deployment, and **GitHub Actions** for CI/CD automation. All three layers are version-controlled and designed for multi-environment support (dev, staging, prod).

## Directory Structure

```
devops-platform/
├── terraform/
│   └── modules/
│       ├── vpc/          # Network infrastructure
│       ├── eks/          # Kubernetes cluster
│       ├── ecr/          # Container registries
│       └── iam/          # Roles and policies
├── kubernetes/
│   └── base/             # Shared K8s manifests (Kustomize base)
├── .github/workflows/
│   ├── ci.yaml           # Build and push (reusable)
│   ├── deploy.yaml       # Deploy to environment
│   └── infra.yaml        # Terraform plan/apply
├── templates/
│   └── new-service/      # Starter template for onboarding
└── docs/
    ├── architecture.md   # This file
    └── onboarding.md     # New service guide
```

## Infrastructure Layer (Terraform)

Four modules provision all AWS resources:

| Module | Purpose | Key Outputs |
|--------|---------|-------------|
| **vpc** | VPC, subnets (3 public + 3 private), IGW, NAT gateway | `vpc_id`, `private_subnet_ids`, `public_subnet_ids` |
| **eks** | EKS cluster, managed node group, OIDC provider for IRSA | `cluster_endpoint`, `cluster_name`, `oidc_provider_arn` |
| **ecr** | Per-service container registry, lifecycle policies | `repository_urls` |
| **iam** | Cluster/node roles, GitHub Actions OIDC deployer role | `cluster_role_arn`, `node_role_arn`, `deployer_role_arn` |

Infrastructure changes are applied via the `infra.yaml` workflow (plan → manual approval → apply).

## Application Layer (Kubernetes + Kustomize)

The `kubernetes/base/` directory contains shared manifests:

- **Deployment** — container image, resource limits, health probes, configmap env
- **Service** — ClusterIP on port 80 → 8080
- **HPA** — autoscaling 2–10 replicas at 70% CPU
- **Ingress** — nginx ingress controller, path-based routing
- **ConfigMap** — LOG_LEVEL, PORT

Environment overlays (`dev/`, `staging/`, `prod/`) patch replica counts, resource limits, and image tags using Kustomize.

## CI/CD Layer (GitHub Actions)

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **ci.yaml** | Push to main, PRs, `workflow_call` | Test → Build → Push image to ECR |
| **deploy.yaml** | `workflow_dispatch` | Set image via kustomize → `kubectl apply` to target environment |
| **infra.yaml** | `workflow_dispatch`, push to `terraform/**` | Terraform plan → apply with environment protection |

The CI workflow is **reusable** — service repos call it via `workflow_call` with their `service_name` and `dockerfile_path`.

## Adding a New Service

See [onboarding.md](onboarding.md) for the step-by-step guide. The `templates/new-service/` directory contains everything needed: Dockerfile, Kubernetes manifests, and a CI workflow that calls the platform's reusable pipeline.
