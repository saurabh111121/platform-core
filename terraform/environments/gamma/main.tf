terraform {
  backend "s3" {
    bucket = "platform-core-tfstate-230296653961"
    key    = "gamma/terraform.tfstate"
    region = "us-west-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../../modules/vpc"

  environment   = var.environment
  project       = var.project
  enable_ha_nat = false
}

module "iam" {
  source = "../../modules/iam"

  environment  = var.environment
  project      = var.project
  state_bucket = "platform-core-tfstate-230296653961"
}

module "eks" {
  source = "../../modules/eks"

  environment      = var.environment
  project          = var.project
  subnet_ids       = module.vpc.private_subnet_ids
  cluster_role_arn = module.iam.cluster_role_arn
  node_role_arn    = module.iam.node_role_arn
  instance_types   = ["t3.large"]
  min_size         = 2
  max_size         = 5
  desired_size     = 3
}

module "ecr" {
  source = "../../modules/ecr"

  environment   = var.environment
  project       = var.project
  service_names = var.services
}

# --- Optional feature modules (opt-in via var.features) ---

module "cloudwatch" {
  count  = var.features.observability.cloudwatch ? 1 : 0
  source = "../../modules/observability/cloudwatch"

  project     = var.project
  environment = var.environment
}

module "prometheus" {
  count  = var.features.observability.prometheus ? 1 : 0
  source = "../../modules/observability/prometheus"
}

module "argocd" {
  count  = var.features.gitops.argocd ? 1 : 0
  source = "../../modules/gitops/argocd"

  environment = var.environment
}
