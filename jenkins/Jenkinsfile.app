pipeline {
    agent any

    tools {
        maven 'maven'
    }

	parameters {
		string(
			name: 'AWS_REGION',
			defaultValue: 'ap-south-1',
			description: 'AWS Region'
		)
	
		string(
			name: 'ACCOUNT_ID',
			defaultValue: '736865445725',
			description: 'AWS Account ID'
		)
	
		string(
			name: 'ECR_REPO',
			defaultValue: 'microservice-demo',
			description: 'ECR Repository'
		)
	}
	
	environment {
		AWS_REGION = "${params.AWS_REGION}"
		ACCOUNT_ID = "${params.ACCOUNT_ID}"
		ECR_REPO   = "${params.ECR_REPO}"
	
		ECR_URI = "${params.ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/${params.ECR_REPO}"
	}

    stages {

        stage('Build') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'mvn clean package'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    withSonarQubeEnv('SonarQube') {
                        sh '''
                        mvn sonar:sonar \
                        -Dsonar.projectKey=devops-handson-activities
                        '''
                    }
                }
            }
        }

        stage('Upload Artifact to Nexus') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh 'mvn deploy'
                }
            }
        }

        stage('Docker Build') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                    docker build -t microservice-demo:v1 .
                    '''
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                    trivy image \
                    --severity HIGH,CRITICAL \
                    microservice-demo:v1
                    '''
                }
            }
        }

        stage('ECR Login') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                    aws ecr get-login-password \
                    --region $AWS_REGION | \
                    docker login \
                    --username AWS \
                    --password-stdin \
                    $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
                    '''
                }
            }
        }

        stage('Tag Image') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                    docker tag microservice-demo:v1 $ECR_URI:${BUILD_NUMBER}
                    docker tag microservice-demo:v1 $ECR_URI:latest
                    '''
                }
            }
        }

        stage('Push Image To ECR') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh '''
                    docker push $ECR_URI:${BUILD_NUMBER}
                    docker push $ECR_URI:latest
                    '''
                }
            }
        }
    }

    post {

        always {
            echo 'Pipeline execution completed.'
        }

        success {
            echo 'Docker image pushed successfully to ECR.'
        }

        unstable {
            echo 'One or more stages failed, but pipeline continued.'
        }

        failure {
            echo 'Pipeline failed.'
        }
    }
}