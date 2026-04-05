terraform {
  required_providers {
    helm = { source = "hashicorp/helm", version = "~> 2.0" }
  }
}

# Deploy kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
resource "helm_release" "prometheus" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = var.chart_version

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention
  }
}
