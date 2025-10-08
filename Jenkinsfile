pipeline {
    // Użyj dowolnego dostępnego agenta, na którym zainstalowany jest Terraform i Python
    agent any

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
                    # WAŻNE: Zakładamy, że python3 i moduł venv są już zainstalowane na agencie.
                    # Usunięto komendę 'apk add', ponieważ była specyficzna dla kontenera Alpine.
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -r requirements.txt
                    python train.py
                '''
            }
        }
        
        stage('Show MLflow Experiments') {
            steps {
                sh '''
                    . venv/bin/activate
                    mlflow experiments list
                '''
            }
        }

        stage('Show Registered Models') {
            steps {
                sh '''
                    . venv/bin/activate
                    # Uwaga: Ta komenda zadziała, jeśli model został zarejestrowany w MLflow Model Registry.
                    mlflow models list
                '''
            }
        }
    }

    post {
        always {
            echo "Destroying AWS infrastructure..."
            sh 'terraform destroy -auto-approve'
        }
    }
}