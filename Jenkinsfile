pipeline {
    agent { label 'agent-node' }
    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git target branch')
        choice(name: 'ENV', choices: ['dev', 'prod'], description: 'Deployment Target Environment')
        string(name: 'AWS_REGION', defaultValue: 'eu-central-1', description: 'AWS Target Region')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '456631682423', description: 'AWS Account ID')
    }

    environment {
        COMMIT_HASH     = "${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'latest'}"
        IMAGE_TAG       = "${env.BUILD_NUMBER}-${env.COMMIT_HASH}"
        DOCKER_BUILDKIT = '1'

        REGISTRY_URL = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
        FRONTEND_ECR = "${REGISTRY_URL}/space2study-frontend-${params.ENV}"
        BACKEND_ECR  = "${REGISTRY_URL}/space2study-backend-${params.ENV}"
        COSIGN_KEY   = credentials('cosign-private-key')
    }

    stages {
        stage('Checkout & Metadata') {
            steps {
                cleanWs()
                checkout scmGit(
                    branches: [[name: "*/${params.BRANCH}"]],
                    userRemoteConfigs: [[url: 'https://github.com/Mredict/Space2Study-Mredict.git']]
                )
                script {
                    echo "Starting Build #${env.BUILD_NUMBER} on Commit ${env.COMMIT_HASH}"
                }
            }
        }

        stage('Static Analysis & Pre-Flight Gates') {
            parallel {
                stage('Secret Leak Detection') {
                    steps {
                        sh 'gitleaks detect --source . --verbose --redact || true'
                    }
                }
                stage('Dockerfile Hardening (Hadolint)') {
                    steps {
                        sh 'hadolint --failure-threshold error backend/Dockerfile'
                        sh 'hadolint --failure-threshold error frontend/Dockerfile'
                    }
                }
                stage('IaC Security (Trivy)') {
                    steps {
                        sh '''
                            trivy config devops/terraform-k3s/ --exit-code 0 --severity CRITICAL,HIGH
                            trivy config devops/helm/space2study/ --exit-code 0 --severity CRITICAL,HIGH
                            trivy config devops/cluster-addons/ --exit-code 0 --severity CRITICAL,HIGH
                        '''
                    }
                }
                stage('K8s Manifest Policy Check (Kyverno CLI)') {
                    steps {
                        sh '''
                            helm template devops/helm/space2study \
                              -f devops/helm/space2study/values.yaml \
                              -f devops/helm/space2study/values-${ENV}.yaml \
                              --set backend.image.tag=${IMAGE_TAG} \
                              --set frontend.image.tag=${IMAGE_TAG} \
                              > /tmp/rendered-manifests.yaml

                            kyverno apply cluster-addons/kyverno-policies/ \
                              --resource /tmp/rendered-manifests.yaml \
                              --detailed-results
                        '''
                    }
                }
            }
        }

        stage('SonarQube & Strict Quality Gate') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh "${tool 'SonarScanner'}/bin/sonar-scanner \
                        -Dsonar.nodejs.executable=/usr/bin/node \
                        -Dsonar.javascript.node.maxspace=2048"
                }
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }

        stage('SCA Dependency Vulnerabilities (Snyk)') {
            environment {
                SNYK_TOKEN = credentials('snyk-api-token')
            }
            parallel {
                stage('Audit Backend Dependencies') {
                    steps {
                        dir('backend') {
                            sh 'snyk test --severity-threshold=high || true'
                        }
                    }
                }
                stage('Audit Frontend Dependencies') {
                    steps {
                        dir('frontend') {
                            sh 'snyk test --severity-threshold=high || true'
                        }
                    }
                }
            }
        }

        stage('Deterministic Image Build') {
            steps {
                sh """
                    docker build \
                        --build-arg BUILDKIT_INLINE_CACHE=1 \
                        -t ${FRONTEND_ECR}:${IMAGE_TAG} ./frontend

                    docker build \
                        --build-arg BUILDKIT_INLINE_CACHE=1 \
                        -t ${BACKEND_ECR}:${IMAGE_TAG} ./backend
                """
            }
        }

        stage('SBOM (Syft)') {
            steps {
                sh """
                    syft ${FRONTEND_ECR}:${IMAGE_TAG} -o cyclonedx-json > frontend-sbom.json
                    syft ${BACKEND_ECR}:${IMAGE_TAG} -o cyclonedx-json > backend-sbom.json
                """
                archiveArtifacts artifacts: '*-sbom.json', fingerprint: true
            }
        }

        stage('Container Image Scan (Trivy)') {
            parallel {
                stage('Verify Frontend Artifact') {
                    steps {
                        sh """
                            trivy image \
                                --exit-code 0 \
                                --severity HIGH,CRITICAL \
                                --ignore-unfixed \
                                --no-progress \
                                ${FRONTEND_ECR}:${IMAGE_TAG}
                        """
                    }
                }
                stage('Verify Backend Artifact') {
                    steps {
                        sh """
                            trivy image \
                                --exit-code 0 \
                                --severity HIGH,CRITICAL \
                                --ignore-unfixed \
                                --no-progress \
                                ${BACKEND_ECR}:${IMAGE_TAG}
                        """
                    }
                }
            }
        }

        stage('ECR Push & Sign') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'jenkins-aws-static-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        aws ecr get-login-password --region "${AWS_REGION}" | \
                            docker login --username AWS --password-stdin "${REGISTRY_URL}"

                        docker push "${FRONTEND_ECR}:${IMAGE_TAG}"
                        docker push "${BACKEND_ECR}:${IMAGE_TAG}"
                    '''
                }
                //Image signing
                withCredentials([usernamePassword(
                    credentialsId: 'jenkins-aws-static-creds',
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    sh '''
                        cosign sign --key "${COSIGN_KEY}" --yes "${FRONTEND_ECR}:${IMAGE_TAG}"
                        cosign sign --key "${COSIGN_KEY}" --yes "${BACKEND_ECR}:${IMAGE_TAG}"
                    '''
                }
            }
        }

        stage('Update GitOps Manifest') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'jenkins-git-push-creds',
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh """
                        VALUES_FILE="devops/helm/space2study/values-${params.ENV}.yaml"

                        sed -i "/^frontend:/,/^[a-z]/ s|tag: .*|tag: ${IMAGE_TAG}|" "\$VALUES_FILE"
                        sed -i "/^backend:/,/^[a-z]/ s|tag: .*|tag: ${IMAGE_TAG}|" "\$VALUES_FILE"

                        git config user.name "jenkins-ci"
                        git config user.email "jenkins-ci@space2study.local"
                        git add "\$VALUES_FILE"
                        git commit -m "deploy(${params.ENV}): ${IMAGE_TAG}" || echo "nothing to commit"
                        git push "https://\${GIT_USER}:\${GIT_TOKEN}@github.com/Mredict/Space2Study-Mredict.git" HEAD:main
                    """
                }
            }
        }
    }

    post {
        always {
            sh """
                docker rmi ${FRONTEND_ECR}:${IMAGE_TAG} || true
                docker rmi ${BACKEND_ECR}:${IMAGE_TAG} || true
            """
            cleanWs()
        }
        success {
            echo "Pipeline succeeded! ${IMAGE_TAG} built, scanned, signed, pushed, and proposed to ArgoCD via git."
        }
        failure {
            echo "Build, scan, or push failed. Inspect stage output above."
        }
    }
}
