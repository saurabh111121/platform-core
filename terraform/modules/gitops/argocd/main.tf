terraform {
  required_providers {
    helm = { source = "hashicorp/helm", version = "~> 2.0" }
  }
}

# Deploy ArgoCD via Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = var.chart_version

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
}

# ArgoCD Application pointing to this repo's kubernetes/overlays
resource "helm_release" "argocd_app" {
  depends_on       = [helm_release.argocd]
  name             = "platform-core-app"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  create_namespace = false
  version          = "1.6.0"

  values = [
    yamlencode({
      applications = [{
        name      = "platform-core"
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = "kubernetes/overlays/${var.environment}"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "default"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }]
    })
  ]
}
