output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_urls" {
  value = module.ecr.repository_urls
}

output "jenkins_url" {
  value = module.jenkins.jenkins_url
}
