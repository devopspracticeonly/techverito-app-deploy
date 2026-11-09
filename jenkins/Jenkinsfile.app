
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'ap-south-1')
        string(name: 'ACCOUNT_ID', defaultValue: '028231499795')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'test', 'prod'])
    }

    environment {
        FRONTEND_REPO = 'employee-frontend'
        BACKEND_REPO  = 'employee-backend'

        FRONTEND_DIR = 'frontend'
        BACKEND_DIR  = 'backend'

        FRONTEND_DOCKERFILE = 'docker/frontend/Dockerfile'
        BACKEND_DOCKERFILE  = 'docker/backend/Dockerfile'
    }

    stages {

        stage('Checkout') {
            steps {
                script {
                    catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                        checkout scm

                        env.IMAGE_TAG = sh(
                            script: 'git rev-parse --short=12 HEAD',
                            returnStdout: true
                        ).trim()

                        env.REGISTRY =
                            "${params.ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"

                        env.FRONTEND_IMAGE =
                            "${env.REGISTRY}/${env.FRONTEND_REPO}"

                        env.BACKEND_IMAGE =
                            "${env.REGISTRY}/${env.BACKEND_REPO}"

                        env.CHECKOUT_READY = 'true'

                        echo "Git commit: ${env.IMAGE_TAG}"
                        echo "Environment: ${params.ENVIRONMENT}"
                        echo "Registry: ${env.REGISTRY}"
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    script {
                        if (env.CHECKOUT_READY != 'true') {
                            error('Checkout failed. Skipping SonarQube analysis.')
                        }
                    }

                    withSonarQubeEnv('SonarQube') {
                        sh '''
                            set -e

                            sonar-scanner \
                              -Dsonar.projectKey=techverito-employee-management \
                              -Dsonar.projectName="Techverito Employee Management" \
                              -Dsonar.sources=frontend/src,backend \
                              -Dsonar.exclusions="**/node_modules/**,**/build/**,**/vendor/**,**/*.test.js,**/*_test.go" \
                              -Dsonar.sourceEncoding=UTF-8
                        '''
                    }
                }
            }
        }

        stage('Validate Source Files') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                        set -e

                        test -f frontend/package.json
                        test -f backend/go.mod
                        test -f backend/go.sum
                        test -f backend/main.go

                        test -f docker/frontend/Dockerfile
                        test -f docker/backend/Dockerfile

                        echo "All source files and Dockerfiles found."
                    '''
                }
            }
        }

        stage('Build Frontend') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    script {
                        if (env.CHECKOUT_READY != 'true') {
                            error('Checkout failed. Cannot build frontend.')
                        }
                    }

                    sh '''
                        set -e

                        docker build \
                          -f "$FRONTEND_DOCKERFILE" \
                          -t "$FRONTEND_IMAGE:$IMAGE_TAG" \
                          "$FRONTEND_DIR"
                    '''
                }
            }
        }

        stage('Build Backend') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    script {
                        if (env.CHECKOUT_READY != 'true') {
                            error('Checkout failed. Cannot build backend.')
                        }
                    }

                    sh '''
                        set -e

                        docker build \
                          -f "$BACKEND_DOCKERFILE" \
                          -t "$BACKEND_IMAGE:$IMAGE_TAG" \
                          "$BACKEND_DIR"
                    '''
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                        set -e

                        docker image inspect "$FRONTEND_IMAGE:$IMAGE_TAG"
                        docker image inspect "$BACKEND_IMAGE:$IMAGE_TAG"

                        trivy image --exit-code 1 \
                          --severity HIGH,CRITICAL \
                          "$FRONTEND_IMAGE:$IMAGE_TAG"

                        trivy image --exit-code 1 \
                          --severity HIGH,CRITICAL \
                          "$BACKEND_IMAGE:$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('ECR Login') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                        set -e

                        aws ecr get-login-password \
                          --region "$AWS_REGION" |
                        docker login \
                          --username AWS \
                          --password-stdin "$REGISTRY"
                    '''
                }
            }
        }

        stage('Push Frontend Image') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                        set -e

                        docker image inspect "$FRONTEND_IMAGE:$IMAGE_TAG"

                        docker push "$FRONTEND_IMAGE:$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('Push Backend Image') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                        set -e

                        docker image inspect "$BACKEND_IMAGE:$IMAGE_TAG"

                        docker push "$BACKEND_IMAGE:$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('Image Summary') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    echo "Environment: ${params.ENVIRONMENT}"
                    echo "Frontend: ${env.FRONTEND_IMAGE}:${env.IMAGE_TAG}"
                    echo "Backend: ${env.BACKEND_IMAGE}:${env.IMAGE_TAG}"
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
            echo 'Application CI pipeline execution completed.'
        }

        success {
            echo 'Pipeline completed. Check individual stage results.'
        }

        failure {
            echo 'Application pipeline failed.'
        }
    }
}
