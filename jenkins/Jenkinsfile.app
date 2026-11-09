
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'ap-south-1')
        string(name: 'ACCOUNT_ID', defaultValue: '736865445725')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'test', 'prod'])
    }

    environment {
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        AWS_REGION = "${params.AWS_REGION}"

        FRONTEND_REPO = 'employee-frontend'
        BACKEND_REPO  = 'employee-backend'

        FRONTEND_DIR = 'frontend'
        BACKEND_DIR  = 'backend'
    }

    stages {

        stage('Checkout') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    checkout scm

                    script {
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

                        echo "Image tag: ${env.IMAGE_TAG}"
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
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

        stage('Validate source files') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                        set -e
                        test -f "$FRONTEND_DIR/Dockerfile"
                        test -f "$FRONTEND_DIR/package.json"
                        test -f "$BACKEND_DIR/Dockerfile"
                        test -f "$BACKEND_DIR/go.mod"

                        echo "Frontend and backend source files found."
                    '''
                }
            }
        }

        stage('Build Frontend') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                        docker build \
                          -t "$FRONTEND_IMAGE:$IMAGE_TAG" \
                          "$FRONTEND_DIR"
                    '''
                }
            }
        }

        stage('Build Backend') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                        docker build \
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
                        docker push "$FRONTEND_IMAGE:$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('Push Backend Image') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                        docker push "$BACKEND_IMAGE:$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('Image Summary') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    echo "Frontend: ${env.FRONTEND_IMAGE}:${env.IMAGE_TAG}"
                    echo "Backend:  ${env.BACKEND_IMAGE}:${env.IMAGE_TAG}"
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
            echo 'Application CI pipeline completed.'
        }

        success {
            echo 'Pipeline completed. Check individual stages for failures.'
        }

        failure {
            echo 'Application pipeline failed.'
        }
    }
}
