pipeline {
    agent { label 'agent-node' }

    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
        choice(name: 'ENV', choices: ['dev', 'staging', 'prod'], description: 'Target Deployment Environment')
        string(name: 'AWS_REGION', defaultValue: 'eu-central-1', description: 'AWS Region')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '456631682423', description: 'AWS Account ID')
    }

    environment {
        IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'latest'}"
        DOCKER_BUILDKIT = '1'

        FRONTEND_ECR = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/space2study-frontend-${params.ENV}"
        BACKEND_ECR  = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/space2study-backend-${params.ENV}"

        ECS_CLUSTER      = "space2study-cluster-${params.ENV}"
        FRONTEND_SERVICE = "space2study-frontend-${params.ENV}"
        BACKEND_SERVICE  = "space2study-backend-${params.ENV}"
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
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-deployer',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh """
                        aws ecr get-login-password --region ${params.AWS_REGION} | \
                        docker login --username AWS --password-stdin ${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com

                        docker push 456631682423.dkr.ecr.eu-central-1.amazonaws.com/space2study-frontend-dev:${IMAGE_TAG}
                        docker push 456631682423.dkr.ecr.eu-central-1.amazonaws.com/space2study-backend-dev:${IMAGE_TAG}
                    """
                }
            }
        }

        stage('Deploy to AWS ECS') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'aws-jenkins-deployer',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh """
                        aws ecs update-service \
                            --cluster ${ECS_CLUSTER} \
                            --service ${FRONTEND_SERVICE} \
                            --force-new-deployment \
                            --region ${params.AWS_REGION}

                        aws ecs update-service \
                            --cluster ${ECS_CLUSTER} \
                            --service ${BACKEND_SERVICE} \
                            --force-new-deployment \
                            --region ${params.AWS_REGION}
                    """
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
            echo "✅ Deployment of ${IMAGE_TAG} to AWS ECS (${params.ENV}) completed successfully!"
        }
        failure {
            echo "❌ Deployment to ${params.ENV} failed. Check the Jenkins console logs for details."
        }
    }
}