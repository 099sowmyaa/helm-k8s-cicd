pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['install', 'upgrade', 'rollback'],
            description: 'Select the Helm operation'
        )

        string(
            name: 'ROLLBACK_REVISION',
            defaultValue: '1',
            description: 'Helm revision number to rollback to'
        )
    }

    environment {
        AWS_REGION     = 'us-east-1'
        AWS_ACCOUNT_ID = '953289341362'
        ECR_REPO       = 'test-project1'
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        ECR_IMAGE      = "${ECR_REGISTRY}/${ECR_REPO}"

        RELEASE_NAME   = 'firstapp'
        NAMESPACE      = 'default'
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code from GitHub...'
            }
        }

        stage('Docker Build') {
            when {
                expression {
                    params.ACTION != 'rollback'
                }
            }

            steps {
                sh '''
                    echo "===== Docker Build ====="

                    docker build \
                      -t ${ECR_IMAGE}:${BUILD_NUMBER} .
                '''
            }
        }

        stage('ECR Login') {
            when {
                expression {
                    params.ACTION != 'rollback'
                }
            }

            steps {
                sh '''
                    echo "===== ECR Login ====="

                    aws ecr get-login-password \
                      --region ${AWS_REGION} | \
                    docker login \
                      --username AWS \
                      --password-stdin ${ECR_REGISTRY}
                '''
            }
        }

        stage('Push Image to ECR') {
            when {
                expression {
                    params.ACTION != 'rollback'
                }
            }

            steps {
                sh '''
                    echo "===== Push Image to ECR ====="

                    docker push ${ECR_IMAGE}:${BUILD_NUMBER}
                '''
            }
        }
        stage('Create ECR Pull Secret') {
            when {
                expression {
                    params.ACTION != 'rollback'
                }
            }

            steps {
                sh '''
                    echo "===== Creating/Refreshing ECR Pull Secret ====="

                    ECR_PASSWORD=$(aws ecr get-login-password \
                      --region ${AWS_REGION})

                    kubectl create secret docker-registry ecr-registry-secret \
                      --namespace ${NAMESPACE} \
                      --docker-server=${ECR_REGISTRY} \
                      --docker-username=AWS \
                      --docker-password="${ECR_PASSWORD}" \
                      --dry-run=client -o yaml | kubectl apply -f -
                '''
            }
        }

        stage('Validate Helm Chart') {
            steps {
                sh '''
                    echo "===== Helm Lint ====="

                    helm lint .

                    echo "===== Helm Template ====="

                    helm template ${RELEASE_NAME} . \
                      --set image.repository=${ECR_IMAGE} \
                      --set image.tag=${BUILD_NUMBER}
                '''
            }
        }

        stage('Helm Install') {
            when {
                expression {
                    params.ACTION == 'install'
                }
            }

            steps {
                sh '''
                    echo "===== Helm Install ====="

                    helm install ${RELEASE_NAME} . \
                      --namespace ${NAMESPACE} \
                      --set image.repository=${ECR_IMAGE} \
                      --set image.tag=${BUILD_NUMBER} \
                      --wait
                '''
            }
        }

        stage('Helm Upgrade') {
            when {
                expression {
                    params.ACTION == 'upgrade'
                }
            }

            steps {
                sh '''
                    echo "===== Helm Upgrade ====="

                    helm upgrade ${RELEASE_NAME} . \
                      --namespace ${NAMESPACE} \
                      --set image.repository=${ECR_IMAGE} \
                      --set image.tag=${BUILD_NUMBER} \
                      --wait
                '''
            }
        }

        stage('Helm Rollback') {
            when {
                expression {
                    params.ACTION == 'rollback'
                }
            }

            steps {
                sh '''
                    echo "===== Helm Rollback ====="

                    helm rollback ${RELEASE_NAME} ${ROLLBACK_REVISION} \
                      --namespace ${NAMESPACE} \
                      --wait
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "======================================"
                    echo "       HELM RELEASE"
                    echo "======================================"

                    helm list -n ${NAMESPACE}

                    echo "======================================"
                    echo "       HELM HISTORY"
                    echo "======================================"

                    helm history ${RELEASE_NAME} \
                      -n ${NAMESPACE}

                    echo "======================================"
                    echo "       KUBERNETES DEPLOYMENT"
                    echo "======================================"

                    kubectl get deployment ${RELEASE_NAME} \
                      -n ${NAMESPACE}

                    echo "======================================"
                    echo "       ROLLOUT STATUS"
                    echo "======================================"

                    kubectl rollout status \
                      deployment/${RELEASE_NAME} \
                      -n ${NAMESPACE} \
                      --timeout=120s

                    echo "======================================"
                    echo "       KUBERNETES PODS"
                    echo "======================================"

                    kubectl get pods -n ${NAMESPACE}

                    echo "======================================"
                    echo "       KUBERNETES SERVICE"
                    echo "======================================"

                    kubectl get service ${RELEASE_NAME} \
                      -n ${NAMESPACE}
                '''
            }
        }
    }

    post {
        success {
            echo '''
========================================
   HELM + ECR PIPELINE SUCCESSFUL
========================================
'''
        }

        failure {
            echo '''
========================================
   HELM + ECR PIPELINE FAILED
========================================
'''
        }
    }
}
