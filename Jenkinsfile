pipeline {
    agent { label 'agent-node' } 

    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
        choice(name: 'ENV', choices: ['dev', 'staging', 'prod'], description: 'Target Deployment Environment')
        string(name: 'REGISTRY', defaultValue: '192.168.56.15:5000', description: 'Docker Registry URI')
    }

    environment {
        IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'latest'}"
        // Enable Docker BuildKit for better performance and caching
        DOCKER_BUILDKIT = '1'

        DEPLOY_TARGET = "${params.ENV == 'dev' ? '192.168.56.20' : (params.ENV == 'staging' ? '192.168.56.30' : '10.0.0.50')}"
    }

    stages {
        stage('Checkout') {
            steps {
                retry(3) { 
                    git branch: "${params.BRANCH}", url: 'https://github.com/Mredict/Space2Study-Mredict.git'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh "${tool 'SonarScanner'}/bin/sonar-scanner \
                        -Dsonar.projectKey=Space2Study \
                        -Dsonar.projectName=Space2Study \
                        -Dsonar.sources=. \
                        -Dsonar.exclusions=node_modules/**,**/tests/**" 
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
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
                        echo "🔍 Scanning Backend Dependencies..."
                        dir('backend') {
                            sh "snyk test --severity-threshold=high || true" 
                        }
                    }
                }
                stage('Scan Frontend') {
                    steps {
                        echo "🔍 Scanning Frontend Dependencies..."
                        dir('frontend') {
                            sh "snyk test --severity-threshold=high || true"
                        }
                    }
                }
            }
        }

        stage('Prepare Secrets & Build Images') {
            steps {
                withCredentials([
                    file(credentialsId: 'backend-env-file', variable: 'BACKEND_ENV'),
                    file(credentialsId: 'frontend-env-file', variable: 'FRONTEND_ENV')
                ]) {
                    sh 'cp $BACKEND_ENV backend/.env'
                    sh 'cp $FRONTEND_ENV frontend/.env'
                    sh 'cp $FRONTEND_ENV .env' 

                    sh "IMAGE_TAG=${IMAGE_TAG} REGISTRY=${params.REGISTRY} docker compose build"
                }
            }
        }

        stage('Container Security Scan (Trivy)') {
            steps {
                parallel(
                    "Scan Frontend Image": {
                        sh """
                            trivy image \
                            --severity HIGH,CRITICAL \
                            --exit-code 0 \
                            --no-progress \
                            --ignore-unfixed \
                            ${params.REGISTRY}/space2study-frontend:${IMAGE_TAG}
                        """
                    },
                    "Scan Backend Image": {
                        sh """
                            trivy image \
                            --severity HIGH,CRITICAL \
                            --exit-code 0 \
                            --no-progress \
                            --ignore-unfixed \
                            ${params.REGISTRY}/space2study-backend:${IMAGE_TAG}
                        """
                    }
                )
            }
        }

        stage('Push to Registry') {
            steps {
                retry(3) {
                    sh "IMAGE_TAG=${IMAGE_TAG} REGISTRY=${params.REGISTRY} docker compose push"
                }
            }
        }

        stage('Deploy via Ansible') {
            steps {
                ansiblePlaybook(
                    playbook: 'devops/configuration_management/ansible/deploy-app.yml',
                    inventory: "${DEPLOY_TARGET},",
                    credentialsId: 'deploy-server-ssh',
                    hostKeyChecking: true,
                    extraVars: [
                        workspace_path: "${env.WORKSPACE}",
                        image_tag: "${IMAGE_TAG}",
                        target_env: "${params.ENV}"
                    ]
                )
            }
        }
    }

    post {
        always {
            sh 'rm -f backend/.env frontend/.env .env'
            cleanWs()
        }
        success {
            echo "✅ Deployment of ${IMAGE_TAG} to ${params.ENV} completed successfully! Access the app at http://${params.DEPLOY_TARGET}"
        }
        failure {
            echo "❌ Deployment to ${params.ENV} failed. Check the Jenkins console logs for details."
        }
    }
}