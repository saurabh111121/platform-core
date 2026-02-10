terraform {
  backend "s3" {
    bucket = "PLACEHOLDER-terraform-state"
    key    = "prod/terraform.tfstate"
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
  enable_ha_nat = true
}

module "iam" {
  source = "../../modules/iam"

  environment = var.environment
  project     = var.project
}

module "eks" {
  source = "../../modules/eks"

  environment      = var.environment
  project          = var.project
  subnet_ids       = module.vpc.private_subnet_ids
  cluster_role_arn = module.iam.cluster_role_arn
  node_role_arn    = module.iam.node_role_arn
  instance_types   = ["t3.xlarge"]
  min_size         = 3
  max_size         = 10
  desired_size     = 5
}

module "ecr" {
  source = "../../modules/ecr"

  environment   = var.environment
  project       = var.project
  service_names = var.services
}
