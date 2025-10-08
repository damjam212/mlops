pipeline {
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

        stage('Provision Infrastructure') {
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

        stage('Install Dependencies & Train Model') {
            steps {
                sh '''
                    # Instalujemy zależności bezpośrednio w środowisku systemowym agenta
                    pip3 install -r requirements.txt
                    
                    # Uruchamiamy skrypt treningowy
                    python3 train.py
                '''
            }
        }
        
        stage('Show MLflow Experiments') {
            steps {
                sh 'mlflow experiments list'
            }
        }

        stage('Show Registered Models') {
            steps {
                sh 'mlflow models list'
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