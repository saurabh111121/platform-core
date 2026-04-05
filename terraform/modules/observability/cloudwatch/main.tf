terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# CloudWatch Log Group for EKS pod logs
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.project}-${var.environment}/pods"
  retention_in_days = var.log_retention_days
  tags              = { Environment = var.environment, Project = var.project }
}

# Enable CloudWatch Container Insights on EKS
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = "${var.project}-${var.environment}"
  addon_name   = "amazon-cloudwatch-observability"
}
