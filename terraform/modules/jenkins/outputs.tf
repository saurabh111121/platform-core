output "jenkins_url" {
  value       = "http://${aws_lb.jenkins.dns_name}"
  description = "Jenkins ALB URL — update JENKINS_URL GitHub secret with this value"
}

output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}
