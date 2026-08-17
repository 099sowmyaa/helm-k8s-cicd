pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['install', 'upgrade', 'rollback'],
            description: 'Select the Helm operation to perform'
        )

        string(
            name: 'IMAGE_TAG',
            defaultValue: '1.0',
            description: 'Docker image tag to deploy'
        )

        string(
            name: 'ROLLBACK_REVISION',
            defaultValue: '1',
            description: 'Helm revision number to rollback to'
        )
    }

    environment {
        RELEASE_NAME = 'firstapp'
        CHART_PATH   = '.'
        NAMESPACE    = 'default'
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out Helm chart from GitHub...'
            }
        }

        stage('Validate Helm Chart') {
            steps {
                sh '''
                    helm lint ${CHART_PATH}
                    helm template ${RELEASE_NAME} ${CHART_PATH} \
                        --set image.tag=${IMAGE_TAG}
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
                    helm install ${RELEASE_NAME} ${CHART_PATH} \
                        --namespace ${NAMESPACE} \
                        --set image.tag=${IMAGE_TAG}
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
                    helm upgrade ${RELEASE_NAME} ${CHART_PATH} \
                        --namespace ${NAMESPACE} \
                        --set image.tag=${IMAGE_TAG} \
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
                    helm rollback ${RELEASE_NAME} ${ROLLBACK_REVISION} \
                        --namespace ${NAMESPACE} \
                        --wait
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "===== Helm Release ====="
                    helm list -n ${NAMESPACE}

                    echo "===== Helm History ====="
                    helm history ${RELEASE_NAME} -n ${NAMESPACE}

                    echo "===== Kubernetes Pods ====="
                    kubectl get pods -n ${NAMESPACE}

                    echo "===== Kubernetes Service ====="
                    kubectl get service ${RELEASE_NAME} -n ${NAMESPACE}
                '''
            }
        }
    }

    post {
        success {
            echo '======================================'
            echo 'HELM DEPLOYMENT SUCCESSFUL'
            echo '======================================'
        }

        failure {
            echo '======================================'
            echo 'HELM DEPLOYMENT FAILED'
            echo '======================================'
        }
    }
}
