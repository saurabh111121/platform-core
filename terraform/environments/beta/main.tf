terraform {
  backend "s3" {
    bucket = "platform-core-tfstate-230296653961"
    key    = "beta/terraform.tfstate"
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
  instance_types   = ["t3.medium"]
  min_size         = 1
  max_size         = 3
  desired_size     = 2
}

module "ecr" {
  source = "../../modules/ecr"

  environment   = var.environment
  project       = var.project
  service_names = var.services
}

module "jenkins" {
  source = "../../modules/jenkins"

  project           = var.project
  region            = var.region
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  public_subnet_ids = module.vpc.public_subnet_ids
  state_bucket      = "platform-core-tfstate-230296653961"
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
