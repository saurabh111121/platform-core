output "cluster_role_arn" {
  value = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}

output "deployer_role_arn" {
  value = aws_iam_role.deployer.arn
}
