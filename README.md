# Platform Core

An infrastructure-as-code platform for deploying containerized services on AWS EKS. It provides reusable Terraform modules, Kustomize-based Kubernetes manifests, GitHub Actions triggers, and a Jenkins CI/CD pipeline across three environments (beta, gamma, prod).

## Architecture

```
  ┌─────────────────────────────────────────────────────────────────┐
  │                        GitHub (SCM)                             │
  │              Push / PR → branch protection rules                │
  └──────────────────────────┬──────────────────────────────────────┘
                             │ webhook / API trigger
  ┌──────────────────────────▼──────────────────────────────────────┐
  │                    GitHub Actions (trigger layer)               │
  │         ci.yaml · deploy.yaml · infra.yaml · auto-destroy.yaml  │
  └──────────────────────────┬──────────────────────────────────────┘
                             │ Jenkins API call
  ┌──────────────────────────▼──────────────────────────────────────┐
  │              Jenkins on EC2 (CI/CD orchestrator)                │
  │  GitLeaks · Semgrep · Checkov · Test · Build · Trivy · Push     │
  │              Terraform Apply → K8s Deploy                       │
  └────────┬──────────────────┬──────────────────────┬──────────────┘
           │                  │                      │
    docker push          terraform apply        kubectl apply
           │                  │                      │
  ┌────────▼──────┐  ┌────────▼──────────┐  ┌────────▼──────────────┐
  │     ECR       │  │   AWS Resources   │  │    EKS Cluster        │
  │  (per-svc)    │  │  VPC/IAM/EKS/ECR  │  │  beta·gamma·prod      │
  └───────────────┘  └───────────────────┘  │  (Kustomize overlays) │
                                            │                       │
                                            │  ┌─────────────────┐  │
                                            │  │ opt-in modules  │  │
                                            │  │ · CloudWatch    │  │
                                            │  │ · Prometheus    │  │
                                            │  │ · ArgoCD        │  │
                                            │  └─────────────────┘  │
                                            └───────────────────────┘
```

Four layers work together:

1. GitHub Actions — lightweight trigger layer, fires on push/PR and calls Jenkins via API
2. Jenkins (EC2) — full CI/CD orchestrator with opt-in DevSecOps scanning: GitLeaks → Semgrep → Checkov → Test → Build → Trivy → Push → Terraform → Deploy
3. Terraform — provisions all AWS infrastructure (VPC, EKS, ECR, IAM, Jenkins EC2) plus opt-in modules (CloudWatch, Prometheus, ArgoCD)
4. Kubernetes + Kustomize — defines app deployments with per-environment overlays (beta/gamma/prod)

## Directory Structure

```
platform-core/
├── .github/
│   └── workflows/
│       ├── ci.yaml             # Trigger: calls Jenkins CI job on push/PR
│       ├── deploy.yaml         # Trigger: calls Jenkins deploy job
│       ├── infra.yaml          # Trigger: calls Jenkins infra job on terraform/** changes
│       └── auto-destroy.yaml   # Scheduled: destroys beta every 40 minutes
├── github-actions-standalone/  # Standalone GitHub Actions (no Jenkins) — use as alternative
│   ├── ci.yaml
│   ├── deploy.yaml
│   ├── infra.yaml
│   └── auto-destroy.yaml
├── Jenkinsfile                 # Full pipeline: test → build → push → terraform → deploy
├── jenkins/
│   ├── Dockerfile              # Jenkins image with Docker, kubectl, kustomize, terraform, AWS CLI
│   ├── plugins.txt             # Required Jenkins plugins
│   └── docker-compose.yaml     # Local development only
├── config/
│   └── constants.yaml          # Central configuration — all tuneable values in one place
├── terraform/
│   ├── modules/
│   │   ├── vpc/                # VPC, subnets, NAT gateways, route tables
│   │   ├── eks/                # EKS cluster, managed node group, OIDC provider
│   │   ├── ecr/                # Container registries with lifecycle policies
│   │   ├── iam/                # Cluster, node, and GitHub Actions deployer roles
│   │   ├── jenkins/            # Jenkins EC2, ALB, IAM role, EBS volume
│   │   ├── observability/
│   │   │   ├── cloudwatch/     # CloudWatch log groups + Container Insights (opt-in)
│   │   │   └── prometheus/     # Prometheus + Grafana via Helm (opt-in)
│   │   └── gitops/
│   │       └── argocd/         # ArgoCD + auto-sync Application via Helm (opt-in)
│   └── environments/
│       ├── beta/               # t3.medium, 1–3 nodes, single NAT
│       ├── gamma/              # t3.large, 2–5 nodes, single NAT
│       └── prod/               # t3.xlarge, 3–10 nodes, HA NAT (3 gateways)
├── kubernetes/
│   ├── base/                   # Deployment, Service, Ingress, HPA, ConfigMap
│   └── overlays/
│       ├── beta/               # 1 replica, debug logging, minimal resources
│       ├── gamma/              # 2 replicas, info logging
│       └── prod/               # 3 replicas, warn logging, 1 CPU / 1Gi limits
├── templates/
│   └── new-service/            # Starter template for onboarding new services
└── docs/
    ├── architecture.md         # Detailed architecture reference
    ├── onboarding.md           # Step-by-step new service guide
    └── further_improvements.md # DevSecOps and SRE improvement roadmap
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

This creates the VPC, EKS cluster, ECR repositories, IAM roles, and the Jenkins EC2 instance with ALB.

### 2. Configure Jenkins

After `terraform apply` completes:

```bash
# Get the Jenkins URL
terraform output jenkins_url
```

1. Open the URL in your browser
2. Go to Manage Jenkins → Credentials → Add `aws-credentials` (AWS Credentials type)
3. Create a Pipeline job pointing to this repo's `Jenkinsfile`
4. Update the `JENKINS_URL` GitHub secret with the ALB URL

### 3. Trigger a Pipeline

Push to `main` — GitHub Actions will automatically trigger the Jenkins CI job. For deploy and infra, use the Actions tab → workflow dispatch.

### 4. Add a New Service

```bash
# Copy the template
cp -r templates/new-service/ ~/repos/my-service/

# Replace placeholders
find ~/repos/my-service -type f -name '*.yaml' | xargs sed -i 's/{{SERVICE_NAME}}/my-service/g'
find ~/repos/my-service -type f -name '*.yaml' | xargs sed -i 's|{{IMAGE}}|230296653961.dkr.ecr.us-west-2.amazonaws.com/my-service:latest|g'

# Add the service to terraform.tfvars in each environment
# services = ["api", "web", "worker", "my-service"]
```

See [docs/onboarding.md](docs/onboarding.md) for the full walkthrough.

## Infrastructure Details

### Terraform Modules

| Module | Resources | Key Config |
|--------|-----------|------------|
| **vpc** | VPC, 3 public + 3 private subnets, IGW, NAT gateway(s), route tables | `enable_ha_nat` for prod (3 NATs across AZs) |
| **eks** | EKS cluster (v1.30), managed node group, OIDC provider for IRSA | Instance types and scaling per environment |
| **ecr** | Per-service repositories, immutable tags, scan-on-push | Lifecycle: expire untagged after 7 days, keep last 20 tagged |
| **iam** | EKS cluster role, node role, GitHub Actions OIDC deployer role | Passwordless CI/CD via OIDC federation |
| **jenkins** | EC2 instance, ALB, EBS volume, IAM role | Jenkins on Amazon Linux 2023, 50GB persistent home |
| **observability/cloudwatch** | CloudWatch log groups, EKS Container Insights addon | Opt-in via `features.observability.cloudwatch = true` |
| **observability/prometheus** | kube-prometheus-stack (Prometheus + Grafana + Alertmanager) | Opt-in via `features.observability.prometheus = true` |
| **gitops/argocd** | ArgoCD + ArgoCD Application with auto-sync | Opt-in via `features.gitops.argocd = true` |

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

GitHub Actions acts as a thin trigger layer — on push/PR it calls Jenkins via API. Jenkins owns the full pipeline.

### GitHub Actions (trigger layer)

The workflows in `.github/workflows/` only trigger Jenkins jobs via the Jenkins API. They require three GitHub secrets: `JENKINS_URL`, `JENKINS_USER`, `JENKINS_API_TOKEN`.

- `ci.yaml` — triggers on push to `main` and PRs, calls Jenkins CI job
- `deploy.yaml` — manual dispatch, triggers Jenkins deploy job for selected environment
- `infra.yaml` — triggers on `terraform/**` changes or manual dispatch, calls Jenkins infra job
- `auto-destroy.yaml` — scheduled every 40 minutes, destroys beta to save costs

For teams that want to skip Jenkins and run GitHub Actions directly, use the workflows in `github-actions-standalone/`.

### Jenkins (CI/CD orchestrator on EC2)

Jenkins is provisioned on EC2 via `terraform/modules/jenkins`. After `terraform apply`, grab the `jenkins_url` output and update the `JENKINS_URL` GitHub secret.

Pipeline stages (`Jenkinsfile`):
- `Test` — run test suite
- `Build` — docker build
- `Push` — push to ECR (main branch only)
- `Terraform Plan` — always runs, archives the plan artifact
- `Terraform Apply` — gated by `INFRA_APPLY` param + manual approval for gamma/prod
- `Deploy` — gated by `DEPLOY` param + manual approval for gamma/prod

Setup after provisioning:
1. Open the `jenkins_url` output in your browser
2. Go to Manage Jenkins → Credentials → Add `aws-credentials` (type: AWS Credentials)
3. Create a Pipeline job pointing to this repo's `Jenkinsfile`

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

## Feature Flags

Optional modules are disabled by default. Enable them per environment by adding to `terraform/environments/<env>/terraform.tfvars`:

```hcl
features = {
  devsecops = {
    trivy    = false  # Container image CVE scanning in Jenkins pipeline
    checkov  = false  # Terraform IaC misconfiguration scanning
    semgrep  = false  # SAST static code analysis
    gitleaks = false  # Secrets scanning
  }
  observability = {
    cloudwatch = true   # CloudWatch log groups + Container Insights
    prometheus = false  # Prometheus + Grafana + Alertmanager via Helm
  }
  gitops = {
    argocd = false  # ArgoCD pull-based GitOps with auto-sync
  }
}
```

DevSecOps scanning stages in the Jenkinsfile are activated via Jenkins environment variables: `ENABLE_TRIVY`, `ENABLE_CHECKOV`, `ENABLE_SEMGREP`, `ENABLE_GITLEAKS`.

Feature branches available for reference:
- `feature/devsecops` — Jenkinsfile scanning stages
- `feature/observability` — CloudWatch + Prometheus Terraform modules
- `feature/gitops` — ArgoCD Terraform module

## Configuration

All tuneable values (AWS account ID, ECR registry, EKS cluster names, services list, environment sizing, container defaults, etc.) are centralized in [`config/constants.yaml`](config/constants.yaml). Update the `TODO` placeholders before deploying.

## Documentation

- [Architecture Overview](docs/architecture.md) — detailed infrastructure and application layer reference
- [Onboarding Guide](docs/onboarding.md) — step-by-step instructions for adding a new service
