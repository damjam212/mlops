pipeline {
    // Use an agent with Terraform and Python installed.
    // You may need to configure a specific agent label.
    agent any

    environment {
        // Define the Terraform directory and the AWS region
        TERRAFORM_DIR       = 'terraform'
        AWS_REGION          = 'eu-north-1'
        // This will be populated dynamically after Terraform runs
        MLFLOW_TRACKING_URI = ''
    }

    stages {
        // Stage 1: Checkout the source code
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // --- Infrastructure Provisioning Stages ---
        // Note: The Jenkins agent running this pipeline needs AWS credentials
        // and Terraform installed.

        stage('Terraform Init') {
            steps {
                dir(TERRAFORM_DIR) {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir(TERRAFORM_DIR) {
                    // -auto-approve is used for automation. In a production setup,
                    // a manual approval step after `terraform plan` is recommended.
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        // Stage 2: Capture Terraform Output and Set Environment
        stage('Set MLflow URI from Terraform') {
            steps {
                script {
                    // Execute `terraform output` and capture the result into a variable
                    def mlflow_ip = dir(TERRAFORM_DIR) {
                        sh(script: 'terraform output -raw mlflow_server_public_ip', returnStdout: true).trim()
                    }
                    
                    if (mlflow_ip) {
                        // Set the MLFLOW_TRACKING_URI for all subsequent stages
                        env.MLFLOW_TRACKING_URI = "http://${mlflow_ip}:5000"
                        echo "Successfully set MLFLOW_TRACKING_URI to: ${env.MLFLOW_TRACKING_URI}"
                    } else {
                        error "Failed to get MLflow server IP from Terraform output."
                    }
                }
            }
        }

        // --- Model Training Stages ---

        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Train Model') {
            steps {
                sh '''
                    . venv/bin/activate
                    echo "Starting model training with MLflow server at $MLFLOW_TRACKING_URI"
                    python train.py
                    echo "Model training finished."
                '''
            }
        }

        // Stage 3: Display MLflow Runs in the Jenkins Log
        stage('Show MLflow Runs') {
            steps {
                sh '''
                    . venv/bin/activate
                    echo "--- MLflow Runs in Experiment: Iris-Classification-Experiment ---"
                    # Use the MLflow CLI to list all runs for the specified experiment
                    mlflow runs list --experiment-name "Iris-Classification-Experiment"
                    echo "-------------------------------------------------------------"
                '''
            }
        }

        // Stage 4: Manual Cleanup of Infrastructure
        stage('DANGER: Destroy Infrastructure') {
            steps {
                // This input step pauses the pipeline and requires manual confirmation
                // before proceeding. This is a critical safety measure.
                input(
                    id: 'confirm-destroy',
                    message: 'Do you want to destroy the AWS infrastructure? This action is irreversible.',
                    ok: 'Yes, Destroy Infrastructure'
                )
                
                // This step will only run if the user provides manual approval.
                dir(TERRAFORM_DIR) {
                    echo "Destroying AWS infrastructure..."
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished."
            // Clean up the Python virtual environment
            sh 'rm -rf venv'
        }
    }
}
