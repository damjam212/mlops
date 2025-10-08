// Jenkinsfile
pipeline {
    // KROK 1: Używamy obrazu Python, który pozwala instalować pakiety i ma już Pythona.
    // Dajemy mu też uprawnienia roota, aby mógł instalować Terraform.
    agent {
        docker { 
            image 'python:3.9-alpine'
            args '-u root'
        }
    }

    environment {
        AWS_REGION          = 'eu-north-1'
        AWS_CREDENTIALS     = credentials('aws-credentials-id')
        // Definiujemy ścieżkę, aby polecenia terraform i mlflow były dostępne
        PATH                = "/usr/local/bin:/usr/bin:/bin:/sbin:${env.WORKSPACE}/venv/bin"
    }

    stages {
        stage('Setup Tools') {
            steps {
                sh '''
                    # KROK 2: Instalujemy Terraform i niezbędne pakiety systemowe
                    echo "--- Installing Tools ---"
                    apk add --no-cache curl unzip git
                    curl -LO https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
                    unzip terraform_1.5.7_linux_amd64.zip
                    mv terraform /usr/local/bin/
                    terraform --version

                    # KROK 3: Tworzymy i aktywujemy środowisko Python raz
                    echo "--- Setting up Python venv ---"
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --no-cache-dir -r requirements.txt
                    echo "------------------------"
                '''
            }
        }

        stage('Provision Infrastructure') {
            steps {
                sh '''
                    echo "--- Running Terraform ---"
                    terraform init
                    terraform validate
                    terraform apply -auto-approve
                    echo "-----------------------"
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
                // KROK 4: Nie musimy już instalować zależności, są gotowe
                sh 'python train.py'
            }
        }

        stage('Show MLflow Experiments & Models') {
            steps {
                sh '''
                    echo "--- Listing MLflow Experiments ---"
                    mlflow experiments list
                    echo "--- Listing Registered Models ---"
                    mlflow models list
                    echo "--------------------------------"
                '''
            }
        }
    }

    post {
        always {
            node {
                echo "Destroying AWS infrastructure..."
                sh 'terraform destroy -auto-approve'
            }
        }
    }
}