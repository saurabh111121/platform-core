pipeline {
    agent any

    /*
     * Parameters mirror the GitHub Actions workflow_dispatch inputs.
     * For CI-only runs (no deploy), leave ENVIRONMENT as 'beta' and
     * set DEPLOY to false.
     */
    parameters {
        string(
            name: 'SERVICE_NAME',
            defaultValue: 'app',
            description: 'Name of the service to build and deploy'
        )
        string(
            name: 'DOCKERFILE_PATH',
            defaultValue: 'Dockerfile',
            description: 'Path to the Dockerfile relative to repo root'
        )
        choice(
            name: 'ENVIRONMENT',
            choices: ['beta', 'gamma', 'prod'],
            description: 'Target environment for deploy and infra stages'
        )
        booleanParam(
            name: 'DEPLOY',
            defaultValue: false,
            description: 'Run the Deploy stage (kubectl apply)'
        )
        booleanParam(
            name: 'INFRA_APPLY',
            defaultValue: false,
            description: 'Run terraform apply (plan always runs)'
        )
    }

    environment {
        AWS_REGION        = 'us-east-1'
        ECR_REGISTRY      = '730667140374.dkr.ecr.us-east-1.amazonaws.com'
        AWS_ACCOUNT_ID    = '730667140374'
        TF_DIR            = "terraform/environments/${params.ENVIRONMENT}"
        IMAGE_TAG         = "${env.GIT_COMMIT?.take(7) ?: 'latest'}"
        IMAGE             = "${ECR_REGISTRY}/${params.SERVICE_NAME}:${IMAGE_TAG}"
    }

    stages {

        // ── 1. Test ────────────────────────────────────────────────
        stage('Test') {
            steps {
                echo "Running test suite for ${params.SERVICE_NAME}"
                // Replace with your actual test command, e.g.:
                // sh 'npm ci && npm test'
                // sh 'go test ./...'
                sh 'echo "Tests passed"'
            }
        }

        // ── 2. Build ───────────────────────────────────────────────
        stage('Build') {
            steps {
                echo "Building Docker image: ${env.IMAGE}"
                sh """
                    docker build \
                        -f ${params.DOCKERFILE_PATH} \
                        -t ${params.SERVICE_NAME}:${env.IMAGE_TAG} \
                        -t ${env.IMAGE} \
                        .
                """
            }
        }

        // ── 3. Push to ECR ─────────────────────────────────────────
        // Only runs on the main branch.
        // Requires Jenkins credential 'aws-credentials' of type
        // "AWS Credentials" (access key + secret key).
        stage('Push') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh """
                        aws ecr get-login-password --region ${env.AWS_REGION} \
                            | docker login --username AWS --password-stdin ${env.ECR_REGISTRY}
                        docker push ${env.IMAGE}
                    """
                }
            }
        }

        // ── 4. Terraform Plan ──────────────────────────────────────
        stage('Terraform Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    dir(env.TF_DIR) {
                        sh 'terraform init -input=false'
                        sh "terraform plan -var-file=terraform.tfvars -out=tfplan"
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: "${env.TF_DIR}/tfplan", allowEmptyArchive: true
                }
            }
        }

        // ── 5. Terraform Apply ─────────────────────────────────────
        // Gated by INFRA_APPLY param + manual input approval for
        // gamma and prod.
        stage('Terraform Apply') {
            when {
                expression { return params.INFRA_APPLY }
            }
            steps {
                script {
                    if (params.ENVIRONMENT in ['gamma', 'prod']) {
                        input message: "Apply Terraform to ${params.ENVIRONMENT}?", ok: 'Apply'
                    }
                }
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    dir(env.TF_DIR) {
                        sh 'terraform apply -input=false tfplan'
                    }
                }
            }
        }

        // ── 6. Deploy ──────────────────────────────────────────────
        // Gated by DEPLOY param + manual input approval for
        // gamma and prod.
        stage('Deploy') {
            when {
                expression { return params.DEPLOY }
            }
            steps {
                script {
                    if (params.ENVIRONMENT in ['gamma', 'prod']) {
                        input message: "Deploy ${params.SERVICE_NAME}:${env.IMAGE_TAG} to ${params.ENVIRONMENT}?", ok: 'Deploy'
                    }
                }
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh """
                        aws eks update-kubeconfig \
                            --name platform-core-${params.ENVIRONMENT} \
                            --region ${env.AWS_REGION}

                        cd kubernetes/overlays/${params.ENVIRONMENT}
                        kustomize edit set image ${params.SERVICE_NAME}=${env.IMAGE}
                        kubectl apply -k .
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully for ${params.SERVICE_NAME}:${env.IMAGE_TAG} → ${params.ENVIRONMENT}"
        }
        failure {
            echo "Pipeline failed — check logs above"
        }
        always {
            // Clean up local docker image to save disk space
            sh "docker rmi ${env.IMAGE} || true"
            sh "docker rmi ${params.SERVICE_NAME}:${env.IMAGE_TAG} || true"
        }
    }
}
