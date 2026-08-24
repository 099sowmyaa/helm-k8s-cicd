pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['install', 'upgrade', 'rollback'],
            description: 'Select the Helm operation'
        )

        choice(
            name: 'DEPLOYMENT_TYPE',
            choices: ['rolling', 'blue-green'],
            description: 'Select deployment strategy'
        )

        choice(
            name: 'BLUE_GREEN_VERSION',
            choices: ['blue', 'green'],
            description: 'For Blue-Green: select which environment should receive traffic'
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

        IMAGE_TAG      = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                echo '===== Checking out source code ====='
                echo 'Source code obtained from GitHub by Jenkins SCM.'
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
                    echo "========================================"
                    echo "           DOCKER BUILD"
                    echo "========================================"

                    docker build \
                      -t ${ECR_IMAGE}:${IMAGE_TAG} .
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
                    echo "========================================"
                    echo "             ECR LOGIN"
                    echo "========================================"

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
                    echo "========================================"
                    echo "          PUSH IMAGE TO ECR"
                    echo "========================================"

                    docker push ${ECR_IMAGE}:${IMAGE_TAG}
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
                    echo "========================================"
                    echo "       REFRESH ECR PULL SECRET"
                    echo "========================================"

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
            when {
                expression {
                    params.ACTION != 'rollback'
                }
            }

            steps {
                sh '''
                    echo "========================================"
                    echo "            HELM LINT"
                    echo "========================================"

                    helm lint .

                    echo "========================================"
                    echo "          HELM TEMPLATE"
                    echo "========================================"

                    helm template ${RELEASE_NAME} . \
                      --set image.repository=${ECR_IMAGE} \
                      --set image.tag=${IMAGE_TAG} \
                      --set service.version=${BLUE_GREEN_VERSION}
                '''
            }
        }

        stage('Helm Install - Rolling') {
            when {
                expression {
                    params.ACTION == 'install' &&
                    params.DEPLOYMENT_TYPE == 'rolling'
                }
            }

            steps {
                sh '''
                    echo "========================================"
                    echo "       ROLLING UPDATE - INSTALL"
                    echo "========================================"

                    helm install ${RELEASE_NAME} . \
                      --namespace ${NAMESPACE} \
                      --set image.repository=${ECR_IMAGE} \
                      --set image.tag=${IMAGE_TAG} \
                      --set service.version=${BLUE_GREEN_VERSION} \
                      --wait
                '''
            }
        }

        stage('Helm Upgrade - Rolling') {
            when {
                expression {
                    params.ACTION == 'upgrade' &&
                    params.DEPLOYMENT_TYPE == 'rolling'
                }
            }

            steps {
                sh '''
                    echo "========================================"
                    echo "          ROLLING UPDATE"
                    echo "========================================"

                    helm upgrade ${RELEASE_NAME} . \
                      --namespace ${NAMESPACE} \
                      --set image.repository=${ECR_IMAGE} \
                      --set image.tag=${IMAGE_TAG} \
                      --set service.version=${BLUE_GREEN_VERSION} \
                      --wait

                    echo "========================================"
                    echo "       ROLLOUT STATUS"
                    echo "========================================"

                    kubectl rollout status \
                      deployment/${RELEASE_NAME} \
                      -n ${NAMESPACE} \
                      --timeout=180s
                '''
            }
        }

        stage('Blue-Green Deploy') {
            when {
                expression {
                    params.ACTION != 'rollback' &&
                    params.DEPLOYMENT_TYPE == 'blue-green'
                }
            }

            steps {
                sh '''
                    echo "========================================"
                    echo "        BLUE-GREEN DEPLOYMENT"
                    echo "========================================"

                    echo "Deploying Blue and Green environments..."

                    helm upgrade --install ${RELEASE_NAME} . \
                      --namespace ${NAMESPACE} \
                      --set image.repository=${ECR_IMAGE} \
                      --set image.tag=${IMAGE_TAG} \
                      --set service.version=${BLUE_GREEN_VERSION} \
                      --wait \
                      --timeout=180s

                    echo "========================================"
                    echo "       BLUE-GREEN PODS"
                    echo "========================================"

                    kubectl get pods \
                      -n ${NAMESPACE} \
                      -l 'version in (blue,green)' \
                      -o wide
                '''
            }
        }

        stage('Blue-Green Traffic Switch') {
            when {
                expression {
                    params.ACTION != 'rollback' &&
                    params.DEPLOYMENT_TYPE == 'blue-green'
                }
            }

            steps {
                sh '''
                    echo "========================================"
                    echo "        BLUE-GREEN TRAFFIC SWITCH"
                    echo "========================================"

                    echo "Traffic will be directed to: ${BLUE_GREEN_VERSION}"

                    helm upgrade ${RELEASE_NAME} . \
                      --namespace ${NAMESPACE} \
                      --set image.repository=${ECR_IMAGE} \
                      --set image.tag=${IMAGE_TAG} \
                      --set service.version=${BLUE_GREEN_VERSION} \
                      --wait \
                      --timeout=180s

                    echo "========================================"
                    echo "       CURRENT SERVICE"
                    echo "========================================"

                    kubectl describe service ${RELEASE_NAME} \
                      -n ${NAMESPACE}
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
                    echo "========================================"
                    echo "           HELM ROLLBACK"
                    echo "========================================"

                    helm rollback ${RELEASE_NAME} ${ROLLBACK_REVISION} \
                      --namespace ${NAMESPACE} \
                      --wait

                    echo "Rollback completed."
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "========================================"
                    echo "             HELM RELEASE"
                    echo "========================================"

                    helm list -n ${NAMESPACE}

                    echo "========================================"
                    echo "             HELM HISTORY"
                    echo "========================================"

                    helm history ${RELEASE_NAME} \
                      -n ${NAMESPACE}

                    echo "========================================"
                    echo "          KUBERNETES PODS"
                    echo "========================================"

                    kubectl get pods \
                      -n ${NAMESPACE} \
                      -o wide

                    echo "========================================"
                    echo "          BLUE-GREEN PODS"
                    echo "========================================"

                    kubectl get pods \
                      -n ${NAMESPACE} \
                      -l 'version in (blue,green)' \
                      -o wide || true

                    echo "========================================"
                    echo "         KUBERNETES SERVICE"
                    echo "========================================"

                    kubectl describe service ${RELEASE_NAME} \
                      -n ${NAMESPACE}

                    echo "========================================"
                    echo "             ENDPOINTS"
                    echo "========================================"

                    kubectl get endpoints ${RELEASE_NAME} \
                      -n ${NAMESPACE}

                    echo "========================================"
                    echo "        ROLLING DEPLOYMENT"
                    echo "========================================"

                    kubectl get deployment ${RELEASE_NAME} \
                      -n ${NAMESPACE} \
                      -o jsonpath='{.spec.strategy.type}{"\\n"}' || true
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
