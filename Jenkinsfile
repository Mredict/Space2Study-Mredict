pipeline {
    agent { label 'agent-node' } // your local PC - authenticates to AWS via IAM Roles Anywhere (see scripts/generate-jenkins-ca.sh), not static keys

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
        // IMAGE_TAG is unique per build and ECR is IMMUTABLE - no ':latest' ever
        // gets pushed, so a tag can't be silently overwritten after Trivy/cosign
        // have already blessed it.
        IMAGE_TAG       = "${env.BUILD_NUMBER}-${env.COMMIT_HASH}"
        DOCKER_BUILDKIT = '1'

        REGISTRY_URL = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
        FRONTEND_ECR = "${REGISTRY_URL}/space2study-frontend-${params.ENV}"
        BACKEND_ECR  = "${REGISTRY_URL}/space2study-backend-${params.ENV}"
        // No KUBECONFIG credential - Jenkins never touches the cluster
        // directly anymore. ArgoCD (in-cluster) handles deployment; see the
        // 'Update GitOps Manifest' stage.
        COSIGN_KEY   = credentials('cosign-private-key') // KMS-backed cosign key ARN, not a raw key file
        // AWS auth: a scoped-down static IAM user, injected only for the
        // stage that needs it (see 'ECR Push & Sign' below), not held in
        // the environment for the whole pipeline. Deliberate fallback from
        // IAM Roles Anywhere, which was built and verified correct
        // end-to-end but hit an unresolved AWS-side certificate rejection -
        // see terraform-k3s modules/iam for the full story. Create the
        // 'jenkins-aws-static-creds' credential in Jenkins (Kind: "Username
        // and password") using the jenkins_access_key_id /
        // jenkins_secret_access_key Terraform outputs as username/password.
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
                        sh 'gitleaks detect --source . --verbose --redact'
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
                            trivy config terraform-k3s/ --exit-code 1 --severity CRITICAL,HIGH
                            trivy config devops/helm/space2study/ --exit-code 1 --severity CRITICAL,HIGH
                            trivy config cluster-addons/ --exit-code 1 --severity CRITICAL,HIGH
                        '''
                    }
                }
                stage('K8s Manifest Policy Check (Kyverno CLI)') {
                    steps {
                        // Renders the chart and checks it against the SAME
                        // policies enforced live in-cluster (cluster-addons/kyverno-policies)
                        // so a bad manifest fails here, in ~10s, instead of at
                        // admission time during the deploy stage.
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
                        -Dsonar.projectKey=space2study \
                        -Dsonar.sources=backend,frontend \
                        -Dsonar.exclusions=**/node_modules/**,**/coverage/**"
                }
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
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
                            sh 'snyk test --severity-threshold=high'
                        }
                    }
                }
                stage('Audit Frontend Dependencies') {
                    steps {
                        dir('frontend') {
                            sh 'snyk test --severity-threshold=high'
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
                // No ':latest' tag is ever built or pushed - ECR is IMMUTABLE,
                // so a second push to the same tag would just fail, and
                // 'latest' as a concept doesn't compose with immutability anyway.
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
                                --exit-code 1 \
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
                                --exit-code 1 \
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
                // Static credentials injected ONLY for this stage's shell
                // steps, not held in the pipeline's environment throughout -
                // limits how long the secret is live in the build's process
                // environment. Jenkins credential ID must be a "Username and
                // password" kind (username = access key ID, password =
                // secret access key) - see the environment{} block comment
                // above for where those values come from.
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
                // cosign keyless-in-spirit but using a KMS-backed key so the
                // private key material never exists on disk on this agent.
                // KMS signing needs its own AWS auth too - same credential.
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
                // This is the ONLY thing Jenkins does that touches
                // deployment - it writes the new image tag into
                // values-<env>.yaml and pushes that commit. ArgoCD (running
                // in-cluster, watching this repo) picks up the change from
                // there. Jenkins never touches kubectl/helm against the
                // cluster directly, and holds no cluster credential at all -
                // that's the whole point of this split.
                //
                // For dev, ArgoCD's automated sync (see
                // cluster-addons/argocd-apps/dev-application.yaml) applies
                // this within ~3 minutes (its default polling interval) with
                // no further action needed. For prod, the Application has NO
                // automated sync policy - this commit only proposes the
                // change; someone still has to run
                // `argocd app sync prod-space2study` (or click Sync in the
                // UI) to actually deploy it. That manual step IS the
                // approval gate now, replacing what used to be a Jenkins
                // `input` step.
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
