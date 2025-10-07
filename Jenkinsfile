pipeline {
    agent {
        docker { image 'hashicorp/terraform:latest' }
    }

    environment {
        AWS_REGION          = 'eu-north-1'
        AWS_CREDENTIALS     = credentials('aws-credentials-id') 
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Provision Infrastructure with Terraform') {
            steps {
                sh '''
                    terraform init
                    terraform validate
                    terraform apply -auto-approve
                '''
            }
        }

        stage('Set MLflow URI') {
            steps {
                script {
                    def mlflow_ip = sh(script: 'terraform output -raw mlflow_server_public_ip', returnStdout: true).trim()
                    if (mlflow_ip) {
                        env.MLFLOW_TRACKING_URI = "http://${mlflow_ip}:5000"
                        echo "MLFLOW_TRACKING_URI set to: ${env.MLFLOW_TRACKING_URI}"
                    } else {
                        error "Failed to get MLflow server IP."
                    }
                }
            }
        }

        stage('Train Model') {
            steps {
                sh '''
                    apk add --no-cache python3 py3-pip
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                    python train.py
                '''
            }
        }

        // --- NOWY ETAP: Wyświetlanie eksperymentów ---
        stage('Show MLflow Experiments') {
            steps {
                sh '''
                    . venv/bin/activate
                    echo "--- Listing MLflow Experiments ---"
                    mlflow experiments list
                    echo "--------------------------------"
                '''
            }
        }

        // --- NOWY ETAP: Wyświetlanie modeli ---
        stage('Show Registered Models') {
            steps {
                sh '''
                    . venv/bin/activate
                    echo "--- Listing Registered Models ---"
                    # Uwaga: Ta komenda zadziała, jeśli model został zarejestrowany.
                    # Twój skrypt loguje model jako artefakt, ale nie rejestruje go.
                    # Aby go zarejestrować, użyj mlflow.register_model()
                    mlflow models list
                    echo "-------------------------------"
                '''
            }
        }
    }

    post {
        always {
            stage('Destroy Infrastructure') {
                steps {
                    echo "Destroying AWS infrastructure..."
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }
}