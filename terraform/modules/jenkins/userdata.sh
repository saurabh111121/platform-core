#!/bin/bash
set -e

# Mount persistent EBS volume for Jenkins home
mkfs.xfs /dev/xvdf 2>/dev/null || true
mkdir -p /var/lib/jenkins
mount /dev/xvdf /var/lib/jenkins
echo "/dev/xvdf /var/lib/jenkins xfs defaults,nofail 0 2" >> /etc/fstab

# Install Java
dnf install -y java-17-amazon-corretto

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins-${jenkins_version}

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker jenkins

# Install kubectl
curl -fsSL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
  -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# Install kustomize
curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" \
  | bash
mv kustomize /usr/local/bin/

# Install Terraform
dnf install -y yum-utils
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform

# Install AWS CLI (already on AL2023 but ensure latest)
dnf install -y aws-cli

# Start Jenkins
systemctl enable jenkins
systemctl start jenkins
