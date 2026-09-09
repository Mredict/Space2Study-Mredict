pipeline {
    agent { label 'agent-node' }

    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
        choice(name: 'ENV', choices: ['dev', 'staging', 'prod'], description: 'Target Deployment Environment')
        string(name: 'AWS_REGION', defaultValue: 'eu-central-1', description: 'AWS Region')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '456631682423', description: 'AWS Account ID')
        string(name: 'K3S_HOST_IP', defaultValue: '', description: 'Public Elastic IP of the K3s host (leave empty to fetch dynamically from AWS)')
    }

    environment {
        IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'latest'}"
        DOCKER_BUILDKIT = '1'

        FRONTEND_ECR = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/space2study-frontend-${params.ENV}"
        BACKEND_ECR  = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/space2study-backend-${params.ENV}"
        
        HELM_RELEASE = "space2study-${params.ENV}"
        K8S_NAMESPACE = "space2study-${params.ENV}"
        CHART_DIR    = "devops/helm"
    }

    stages {
        stage('Checkout') {
            steps {
                retry(3) {
                    git branch: "${params.BRANCH}", url: 'https://github.com/Mredict/Space2Study-Mredict.git'
                }
            }
        }

        stage('Static Code & Security Checks') {
            parallel {
                stage('Secret Scanning (Gitleaks)') {
                    steps {
                        sh 'gitleaks detect --source . --report-format json --report-path gitleaks.json --no-banner || true'
                    }
                }
                stage('Dockerfile Linting (Hadolint)') {
                    steps {
                        sh 'hadolint backend/Dockerfile'
                        sh 'hadolint frontend/Dockerfile'
                    }
                }
                stage('Terraform Security Scan') {
                    steps {
                        sh 'trivy config devops/terraform/ --severity HIGH,CRITICAL || true'
                    }
                }
                stage('Helm Chart Lint & Security') {
                    steps {
                        sh """
                            helm lint ${CHART_DIR}
                            trivy config ${CHART_DIR} --severity HIGH,CRITICAL || true
                        """
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh "${tool 'SonarScanner'}/bin/sonar-scanner \
                        -Dsonar.nodejs.executable=/usr/bin/node \
                        -Dsonar.javascript.node.maxspace=2048"
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }

        stage('SCA Security Scan (Snyk)') {
            environment {
                SNYK_TOKEN = credentials('snyk-token')
            }
            parallel {
                stage('Scan Backend') {
                    steps {
                        dir('backend') {
                            sh "snyk test --severity-threshold=high || true"
                        }
                    }
                }
                stage('Scan Frontend') {
                    steps {
                        dir('frontend') {
                            sh "snyk test --severity-threshold=high || true"
                        }
                    }
                }
            }
        }

        stage('Build Container Images') {
            steps {
                sh """
                    docker build -t ${FRONTEND_ECR}:${IMAGE_TAG} -t ${FRONTEND_ECR}:latest ./frontend
                    docker build -t ${BACKEND_ECR}:${IMAGE_TAG} -t ${BACKEND_ECR}:latest ./backend
                """
            }
        }

        stage('Container Security Scan (Trivy)') {
            parallel {
                stage('Scan Frontend Image') {
                    steps {
                        sh """
                            docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v /root/.cache/trivy-frontend:/root/.cache/trivy \
                            aquasec/trivy:latest image \
                            --severity HIGH,CRITICAL \
                            --exit-code 0 \
                            --no-progress \
                            --ignore-unfixed \
                            ${FRONTEND_ECR}:${IMAGE_TAG}
                        """
                    }
                }
                stage('Scan Backend Image') {
                    steps {
                        sh """
                            docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -v /root/.cache/trivy-backend:/root/.cache/trivy \
                            aquasec/trivy:latest image \
                            --severity HIGH,CRITICAL \
                            --exit-code 0 \
                            --no-progress \
                            --ignore-unfixed \
                            ${BACKEND_ECR}:${IMAGE_TAG}
                        """
                    }
                }
            }
        }

        stage('Push to Amazon ECR') {
            environment {
                AWS_REGION = "${params.AWS_REGION}"
            }
            steps {
                withCredentials([usernamePassword(  
                    credentialsId: 'aws-jenkins-deployer',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        set -e
                        aws ecr get-login-password --region "${AWS_REGION}" | \
                            docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                        docker push "${FRONTEND_ECR}:${IMAGE_TAG}"
                        docker push "${FRONTEND_ECR}:latest"
                        docker push "${BACKEND_ECR}:${IMAGE_TAG}"
                        docker push "${BACKEND_ECR}:latest"
                    '''
                }
            }
        }

        stage('Deploy to K3s (Helm)') {
            environment {
                AWS_REGION = "${params.AWS_REGION}"
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-jenkins-deployer',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    sshUserPrivateKey(
                        credentialsId: 'k3s-ssh-key',
                        keyFileVariable: 'SSH_KEY_PATH',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -e

                        # 1. Resolve K3s host IP
                        TARGET_HOST="${K3S_HOST_IP}"
                        if [ -z "$TARGET_HOST" ]; then
                            TARGET_HOST=$(aws ec2 describe-instances \
                                --filters "Name=tag:Name,Values=space2study-k3s-${ENV}" "Name=instance-state-name,Values=running" \
                                --region "${AWS_REGION}" \
                                --query "Reservations[0].Instances[0].PublicIpAddress" \
                                --output text)
                        fi

                        if [ "$TARGET_HOST" = "None" ] || [ -z "$TARGET_HOST" ]; then
                            echo "ERROR: Unable to locate running K3s instance"
                            exit 1
                        fi

                        echo "Deploying to K3s at: ${TARGET_HOST}"

                        # 2. Fetch runtime secrets from AWS Secrets Manager
                        SECRETS_JSON=$(aws secretsmanager get-secret-value \
                            --secret-id "space2study-app-secrets-${ENV}" \
                            --region "${AWS_REGION}" \
                            --query 'SecretString' \
                            --output text)

                        DB_USER=$(echo "$SECRETS_JSON" | jq -r .DB_USERNAME)
                        DB_PASS=$(echo "$SECRETS_JSON" | jq -r .DB_PASSWORD)
                        JWT_ACCESS=$(echo "$SECRETS_JSON" | jq -r .JWT_ACCESS_SECRET)
                        JWT_REFRESH=$(echo "$SECRETS_JSON" | jq -r .JWT_REFRESH_SECRET)
                        JWT_RESET=$(echo "$SECRETS_JSON" | jq -r .JWT_RESET_SECRET)
                        JWT_CONFIRM=$(echo "$SECRETS_JSON" | jq -r .JWT_CONFIRM_SECRET)
                        MAIL_USER_VAL=$(echo "$SECRETS_JSON" | jq -r .MAIL_USER)
                        MAIL_PASS_VAL=$(echo "$SECRETS_JSON" | jq -r .MAIL_PASS)
                        GMAIL_ID=$(echo "$SECRETS_JSON" | jq -r .GMAIL_CLIENT_ID)
                        GMAIL_SECRET=$(echo "$SECRETS_JSON" | jq -r .GMAIL_CLIENT_SECRET)
                        GMAIL_TOKEN=$(echo "$SECRETS_JSON" | jq -r .GMAIL_REFRESH_TOKEN)
                        GMAIL_URI=$(echo "$SECRETS_JSON" | jq -r .GMAIL_REDIRECT_URI)

                        # 3. Securely transfer the kubeconfig or run deployment over SSH
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$TARGET_HOST" "mkdir -p /tmp/space2study-chart"
                        scp -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" -r ${CHART_DIR}/* "$SSH_USER@$TARGET_HOST:/tmp/space2study-chart/"

                        # 4. Authenticate cluster node's containerd to ECR so K3s can pull images
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$TARGET_HOST" """
                            aws ecr get-login-password --region ${AWS_REGION} | \
                            k3s ctr images login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        """

                        # 5. Execute atomic Helm upgrade/install
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$TARGET_HOST" """
                            helm upgrade --install ${HELM_RELEASE} /tmp/space2study-chart \
                                --namespace ${K8S_NAMESPACE} \
                                --create-namespace \
                                --set global.domain=\"${TARGET_HOST}\" \
                                --set backend.image.repository=\"${BACKEND_ECR}\" \
                                --set backend.image.tag=\"${IMAGE_TAG}\" \
                                --set frontend.image.repository=\"${FRONTEND_ECR}\" \
                                --set frontend.image.tag=\"${IMAGE_TAG}\" \
                                --set secrets.dbUsername=\"${DB_USER}\" \
                                --set secrets.dbPassword=\"${DB_PASS}\" \
                                --set secrets.jwtAccessSecret=\"${JWT_ACCESS}\" \
                                --set secrets.jwtRefreshSecret=\"${JWT_REFRESH}\" \
                                --set secrets.jwtResetSecret=\"${JWT_RESET}\" \
                                --set secrets.jwtConfirmSecret=\"${JWT_CONFIRM}\" \
                                --set secrets.mailUser=\"${MAIL_USER_VAL}\" \
                                --set secrets.mailPass=\"${MAIL_PASS_VAL}\" \
                                --set secrets.gmailClientId=\"${GMAIL_ID}\" \
                                --set secrets.gmailClientSecret=\"${GMAIL_SECRET}\" \
                                --set secrets.gmailRefreshToken=\"${GMAIL_TOKEN}\" \
                                --set secrets.gmailRedirectUri=\"${GMAIL_URI}\" \
                                --wait \
                                --timeout 300s \
                                --atomic
                        """

                        # Clean up remote temp directory
                        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$SSH_USER@$TARGET_HOST" "rm -rf /tmp/space2study-chart"
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
            sh """
                docker rmi ${FRONTEND_ECR}:${IMAGE_TAG} ${FRONTEND_ECR}:latest || true
                docker rmi ${BACKEND_ECR}:${IMAGE_TAG} ${BACKEND_ECR}:latest || true
            """
        }
        success {
            echo "Deployment of ${IMAGE_TAG} to K3s (${params.ENV}) completed successfully!"
        }
        failure {
            echo "Deployment to ${params.ENV} failed. Inspect Helm rollback status and pod logs."
        }
    }
}