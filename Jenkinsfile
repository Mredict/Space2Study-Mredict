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
        
        HELM_VALUES_FILE = "devops/helm/space2study/values.yaml"
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
                stage('Helm & Terraform Security Scan') {
                    steps {
                        sh '''
                            helm lint devops/helm/space2study || true
                            trivy config devops/helm/space2study --severity HIGH,CRITICAL || true
                            trivy config devops/terraform/ --severity HIGH,CRITICAL || true
                        '''
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

        stage('GitOps: Update Manifests (Trigger ArgoCD)') {
            steps {
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh """
                        set -e

                        # 1. Update image tags in values.yaml using yq or sed
                        sed -i 's|tag: .*# backend-tag|tag: "${IMAGE_TAG}" # backend-tag|' ${HELM_VALUES_FILE}
                        sed -i 's|tag: .*# frontend-tag|tag: "${IMAGE_TAG}" # frontend-tag|' ${HELM_VALUES_FILE}

                        # 2. Commit and push the updated Helm values to GitHub
                        git config user.name "jenkins-bot"
                        git config user.email "jenkins-bot@space2study.local"
                        git add ${HELM_VALUES_FILE}
                        
                        # Only commit if changes exist
                        if git diff --staged --quiet; then
                            echo "No changes in image tags to commit."
                        else
                            git commit -m "ci(gitops): update image tags to ${IMAGE_TAG} [skip ci]"
                            git push https://${GITHUB_TOKEN}@github.com/Mredict/Space2Study-Mredict.git HEAD:${params.BRANCH}
                            echo "✅ Successfully updated Helm values in Git. ArgoCD will now sync the deployment."
                        fi
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
            echo "CI pipeline completed. ArgoCD is deploying ${IMAGE_TAG} to ${params.ENV}!"
        }
        failure {
            echo "Pipeline failed. Check stage logs."
        }
    }
}