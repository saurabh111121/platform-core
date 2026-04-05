# Further Improvements

This document tracks what is needed to evolve this platform into a complete DevSecOps and SRE-grade pipeline.

Items marked ✅ are already implemented (opt-in via feature flags). Items marked 🔲 are pending.

---

## 1. Security (DevSecOps)

### Pipeline Scanning
| Tool | Purpose | Status |
|------|---------|--------|
| Trivy | Scan Docker images for CVEs before pushing to ECR | ✅ `ENABLE_TRIVY=true` in Jenkins |
| Checkov | Scan Terraform configs for misconfigurations before apply | ✅ `ENABLE_CHECKOV=true` in Jenkins |
| Semgrep / SonarQube | SAST — static code analysis on every PR | ✅ `ENABLE_SEMGREP=true` in Jenkins |
| GitLeaks / truffleHog | Prevent secrets from being committed | ✅ `ENABLE_GITLEAKS=true` in Jenkins |
| OWASP Dependency Check | Scan for vulnerable packages in application dependencies | 🔲 |

### Runtime Security
| Tool | Purpose | Status |
|------|---------|--------|
| Falco | DaemonSet on EKS for real-time runtime threat detection | 🔲 |
| AWS GuardDuty | Cloud-level threat detection across EC2, EKS, S3, IAM | 🔲 |
| AWS Security Hub | Centralize findings from GuardDuty, Inspector, and Macie | 🔲 |

### Compliance & Governance
| Tool | Purpose | Status |
|------|---------|--------|
| AWS CloudTrail | Full audit logging of all API calls across the account | 🔲 |
| OPA / Gatekeeper | Kubernetes admission policies | 🔲 |
| AWS Config | Track configuration changes and enforce compliance rules | 🔲 |

---

## 2. Reliability (SRE)

### Deployment Strategies
- Canary / blue-green deployments via Argo Rollouts or Flagger — gradually shift traffic (5% → 25% → 100%) and auto-abort on error rate spikes
- Automated rollback — failed readiness probes or elevated error rates trigger automatic rollback without manual intervention

### Service Reliability
- SLOs / SLIs — define Service Level Objectives (e.g. 99.9% availability, p99 latency < 200ms) and track error budgets with burn rate alerts
- Chaos engineering — LitmusChaos or Chaos Monkey to regularly test pod kills, network partitions, and node failures in beta/gamma
- Load testing — add k6, Locust, or Gatling as a pipeline stage before prod promotion to catch performance regressions

### Incident Management
- On-call integration — wire CloudWatch Alarms or Alertmanager to PagerDuty or OpsGenie
- Runbooks — document response procedures for common failures (pod OOMKilled, node not ready, ECR push failure, Terraform state lock) in `docs/runbooks/`
- Post-mortem process — define a blameless post-mortem template for Sev-1/Sev-2 incidents

### Capacity Planning
- Cluster Autoscaler — auto-scale EKS nodes when pods are pending due to insufficient capacity
- VPA (Vertical Pod Autoscaler) — right-size container CPU/memory requests based on actual usage
- Cost monitoring — Kubecost or AWS Cost Explorer with per-namespace tagging to track spend by service and environment

---

## 3. Observability

| Tool | Purpose | Status |
|------|---------|--------|
| CloudWatch log groups + Container Insights | EKS pod logs and cluster metrics | ✅ `features.observability.cloudwatch = true` |
| Prometheus + Grafana | Cluster and app metrics, dashboards | ✅ `features.observability.prometheus = true` |
| Fluent Bit DaemonSet | Ship pod logs to CloudWatch | 🔲 |
| Alertmanager | Fire alerts on failures and high resource usage | 🔲 included with Prometheus stack |
| AWS X-Ray / OpenTelemetry | Distributed tracing across services | 🔲 |

---

## 4. Infrastructure

- Terraform state locking — add DynamoDB table as a lock mechanism to prevent concurrent `terraform apply` from corrupting state
- Gamma and prod provisioning — `terraform init` and first `terraform apply` for gamma and prod has not been run yet
- Jenkins HA — Jenkins runs on a single EC2 instance; run it as a pod inside EKS or use a multi-AZ setup to avoid CI/CD downtime
- Multi-region — currently single region (us-west-2); add cross-region replication for prod resilience

---

## 5. Developer Experience

| Item | Status |
|------|--------|
| Pre-commit hooks (`terraform fmt`, `terraform validate`, YAML linting) | 🔲 |
| Helm — replace Kustomize with Helm for wider adoption | 🔲 |
| ArgoCD / Flux GitOps — pull-based delivery with drift detection | ✅ `features.gitops.argocd = true` |
| Service catalog — self-service onboarding portal (Backstage) | 🔲 |

---

## 6. Networking & Service Mesh

- Service mesh (Istio / Linkerd) — enforce mTLS between services for zero-trust networking, traffic management, circuit breaking, and retries without code changes
- Ingress hardening — add rate limiting, WAF (AWS WAF on ALB), and TLS termination with cert-manager for automatic certificate rotation
- Network policies — restrict pod-to-pod and namespace-to-namespace traffic using Kubernetes NetworkPolicy resources

---

## 7. Multi-tenancy & Kubernetes Best Practices

- Namespaces per team/service — currently everything deploys to `default`; use dedicated namespaces with RBAC roles scoped per team
- Resource quotas — enforce CPU/memory quotas per namespace to prevent noisy-neighbour issues
- Pod Disruption Budgets (PDBs) — define minimum available pods during node drains and rolling updates to maintain availability
- Readiness / liveness probe tuning — document and tune probe thresholds per service to avoid premature traffic routing and unnecessary restarts

---

## 8. Disaster Recovery

- Backup strategy — use Velero to back up EKS workloads and persistent volumes to S3 on a schedule
- Cross-region failover — replicate ECR images and Terraform state to a secondary region; document failover runbook
- RTO / RPO definition — define Recovery Time Objective and Recovery Point Objective per environment (e.g. prod RTO < 1hr, RPO < 15min)

---

## 9. CI/CD Patterns

- Branch strategy — document and enforce a branching model (trunk-based development recommended); add branch protection rules for `main`
- Feature flags — integrate LaunchDarkly or Flagsmith to decouple deployment from release; deploy dark, enable per user/region
- Database migration strategy — add a migration step (Flyway, Liquibase) to the pipeline that runs schema changes safely before app rollout, with automatic rollback on failure

---

## 10. Cost Optimization

- Spot instances for non-prod — run beta and gamma node groups on EC2 Spot to reduce compute costs by 60-70%; use mixed instance policy with on-demand fallback
- Right-sizing — use VPA recommendations and AWS Compute Optimizer to identify over-provisioned instances and containers
- Scheduled scaling — scale down beta/gamma node groups to zero outside business hours using scheduled EKS scaling actions

---

## 11. Platform Engineering

- Internal Developer Platform (IDP) — build on Backstage (Spotify's open-source IDP) to give developers self-service infrastructure, service ownership visibility, docs, and pipeline status in one portal
- Golden paths enforcement — `templates/new-service/` exists but is not enforced; add tooling (cookiecutter, CLI, or Backstage scaffolder) so new services must start from the approved template
- Service catalog — register all services with ownership, SLOs, runbooks, and dependency maps in Backstage or a similar catalog

---

## 12. Advanced Kubernetes

- Multi-cluster management — use Rancher, Fleet, or ArgoCD ApplicationSets to manage beta/gamma/prod EKS clusters from a single control plane
- KEDA (Kubernetes Event-Driven Autoscaling) — scale pods based on SQS queue depth, Kafka consumer lag, or custom metrics rather than just CPU utilization
- Admission webhooks — implement custom validating/mutating webhooks to enforce org-wide policies at deploy time (e.g. require labels, block latest image tags, enforce resource limits)

---

## 13. Compliance & Auditing

- SBOM (Software Bill of Materials) — generate a dependency manifest per Docker image using Syft or CycloneDX and store alongside the image in ECR; increasingly required by enterprise customers and government contracts
- SOC2 / ISO 27001 readiness — implement evidence collection, quarterly access reviews, and change management logs to support compliance audits
- Immutable infrastructure — enforce that no manual changes are made to running infrastructure; all changes must go through Git and the pipeline (detect drift with `terraform plan` on a schedule)

---

## 14. Advanced Observability

- Continuous profiling — deploy Pyroscope or AWS CodeGuru Profiler to identify CPU and memory hotspots in production with minimal overhead
- Real User Monitoring (RUM) — track actual user experience metrics (Core Web Vitals, page load times) using AWS CloudWatch RUM or Datadog RUM, not just infrastructure-level metrics
- Synthetic monitoring — run scheduled synthetic tests (Datadog Synthetics, CloudWatch Synthetics) against prod endpoints to detect outages before users do
