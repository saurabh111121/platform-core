FROM jenkins/jenkins:lts

USER root

# Install dependencies: Docker CLI, kubectl, kustomize, terraform, AWS CLI
RUN apt-get update && apt-get install -y \
    curl unzip gnupg lsb-release ca-certificates apt-transport-https && \
    # Docker CLI
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y docker-ce-cli && \
    # kubectl
    curl -fsSL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
        -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl && \
    # kustomize
    curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" \
        | bash && mv kustomize /usr/local/bin/ && \
    # terraform
    curl -fsSL https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip -o /tmp/tf.zip && \
    unzip /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip && \
    # AWS CLI
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscli.zip && \
    unzip /tmp/awscli.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscli.zip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER jenkins

# Skip setup wizard and install required plugins
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
