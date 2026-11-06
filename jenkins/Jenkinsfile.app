
pipeline {
    agent any

    options {
        timestamps()
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
    }

    parameters {
        choice(
            name: 'DEPLOY_ENV',
            choices: ['dev', 'test', 'prod'],
            description: 'Select the deployment environment'
        )
    }

    environment {
        AWS_REGION       = 'ap-south-1'
        AWS_ACCOUNT_ID   = 'YOUR_AWS_ACCOUNT_ID'

        ECR_BACKEND      = 'employee-backend'
        ECR_FRONTEND     = 'employee-frontend'

        BACKEND_DIR      = 'application/backend'
        FRONTEND_DIR     = 'application/frontend'

        HELM_VALUES      = 'helm/employee-management'
        IMAGE_TAG        = "${BUILD_NUMBER}-${GIT_COMMIT_SHORT}"

        SONAR_PROJECT    = 'employee-management'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                script {
                    env.GIT_COMMIT_SHORT =
                        sh(
                            script: 'git rev-parse --short HEAD',
                            returnStdout: true
                        ).trim()

                    env.IMAGE_TAG =
                        "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"

                    echo "Building image tag: ${env.IMAGE_TAG}"
                    echo "Target environment: ${params.DEPLOY_ENV}"
                }
            }
        }

        stage('Validate Source') {
            steps {
                sh '''
                    set -e

                    test -f application/backend/go.mod
                    test -f application/backend/main.go
                    test -f application/frontend/package.json

                    echo "Source structure validated"
                '''
            }
        }

        stage('Backend Tests') {
            steps {
                dir("${BACKEND_DIR}") {
                    sh '''
                        set -e
                        go mod download
                        go test ./...
                    '''
                }
            }
        }

        stage('Frontend Tests') {
            steps {
                dir("${FRONTEND_DIR}") {
                    sh '''
                        set -e
                        npm ci
                        CI=true npm test -- --watchAll=false
                        npm run build
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=employee-management \
                          -Dsonar.projectName=Employee-Management \
                          -Dsonar.sources=application \
                          -Dsonar.exclusions=**/node_modules/**,**/build/**,**/vendor/**
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    script {
                        def qualityGate = waitForQualityGate()
                        if (qualityGate.status != 'OK') {
                            error "SonarQube Quality Gate failed: ${qualityGate.status}"
                        }
                    }
                }
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                sh '''
                    set -e

                    trivy fs \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      .
                '''
            }
        }

        stage('Build Docker Images') {
            steps {
                sh '''
                    set -e

                    docker build \
                      -t employee-backend:${IMAGE_TAG} \
                      ${BACKEND_DIR}

                    docker build \
                      -t employee-frontend:${IMAGE_TAG} \
                      ${FRONTEND_DIR}
                '''
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                    set -e

                    trivy image \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      employee-backend:${IMAGE_TAG}

                    trivy image \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      employee-frontend:${IMAGE_TAG}
                '''
            }
        }

        stage('Login to AWS ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    sh '''
                        set -e

                        aws sts get-caller-identity

                        aws ecr get-login-password \
                          --region ${AWS_REGION} |
                        docker login \
                          --username AWS \
                          --password-stdin \
                          ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    '''
                }
            }
        }

        stage('Push Images to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    sh '''
                        set -e

                        BACKEND_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_BACKEND}"
                        FRONTEND_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_FRONTEND}"

                        docker tag employee-backend:${IMAGE_TAG} ${BACKEND_IMAGE}:${IMAGE_TAG}
                        docker tag employee-frontend:${IMAGE_TAG} ${FRONTEND_IMAGE}:${IMAGE_TAG}

                        docker push ${BACKEND_IMAGE}:${IMAGE_TAG}
                        docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}
                    '''
                }
            }
        }

        stage('Production Approval') {
            when {
                expression { params.DEPLOY_ENV == 'prod' }
            }
            steps {
                input message: 'Approve production deployment?',
                      ok: 'Approve'
            }
        }

        stage('Update Helm GitOps Values') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'git-credentials',
                    usernameVariable: 'GIT_USERNAME',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh '''
                        set -e

                        VALUES_FILE="${HELM_VALUES}/values-${DEPLOY_ENV}.yaml"

                        test -f "$VALUES_FILE"

                        BACKEND_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_BACKEND}"
                        FRONTEND_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_FRONTEND}"

                        git config user.name "Jenkins"
                        git config user.email "jenkins@example.com"

                        # Requires yq v4
                        yq -i '.backend.image.repository = strenv(BACKEND_IMAGE)' "$VALUES_FILE"
                        yq -i '.backend.image.tag = strenv(IMAGE_TAG)' "$VALUES_FILE"
                        yq -i '.frontend.image.repository = strenv(FRONTEND_IMAGE)' "$VALUES_FILE"
                        yq -i '.frontend.image.tag = strenv(IMAGE_TAG)' "$VALUES_FILE"

                        git add "$VALUES_FILE"

                        if git diff --cached --quiet; then
                            echo "No Helm values changes to commit"
                        else
                            git commit -m "Deploy ${IMAGE_TAG} to ${DEPLOY_ENV}"

                            git push \
                              https://${GIT_USERNAME}:${GIT_TOKEN}@${GIT_URL#https://} \
                              HEAD:${GIT_BRANCH}
                        fi
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "CI pipeline completed successfully."
            echo "Environment: ${params.DEPLOY_ENV}"
            echo "Image tag: ${env.IMAGE_TAG}"
            echo "Argo CD will reconcile the updated Helm values."
        }

        failure {
            echo "Pipeline failed. Check the failed stage and Jenkins logs."
        }

        always {
            sh 'docker logout ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com || true'
            cleanWs()
        }
    }
}
