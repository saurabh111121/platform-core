variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "project" {
  type = string
}

variable "services" {
  type    = list(string)
  default = ["api", "web", "worker"]
}

variable "features" {
  type = object({
    devsecops = object({
      trivy    = bool
      checkov  = bool
      semgrep  = bool
      gitleaks = bool
    })
    observability = object({
      cloudwatch = bool
      prometheus = bool
    })
    gitops = object({
      argocd = bool
    })
  })
  default = {
    devsecops = {
      trivy    = false
      checkov  = false
      semgrep  = false
      gitleaks = false
    }
    observability = {
      cloudwatch = false
      prometheus = false
    }
    gitops = {
      argocd = false
    }
  }
}
