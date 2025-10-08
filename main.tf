terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1" # You can change this to your preferred AWS region
}

# Use the random provider to generate a unique suffix for resource names
# This helps avoid naming conflicts in your AWS account
resource "random_pet" "suffix" {
  length = 2
}

# Define a common set of tags to be applied to all resources
locals {
  default_tags = {
    Owner   = "dkakol"
    Project = "ml/mlops-internship"
  }
}

# 1. S3 Bucket for MLflow Artifacts
# This bucket will store the model artifacts, such as trained models, plots, etc.
resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket = "dkakol-mlflow-artifacts-${random_pet.suffix.id}"

  tags = merge(local.default_tags, {
    Name = "dkakol-mlflow-artifacts-${random_pet.suffix.id}"
  })
}

# 2. IAM Role and Policy for EC2 to Access S3
# Using existing instance profile "vbujoreanu-ec2-s3_access-role"

# 3. Security Group for the EC2 Instance
# This acts as a virtual firewall for the instance, controlling inbound and outbound traffic.
resource "aws_security_group" "mlflow_sg" {
  name        = "dkakol-mlflow-sg-${random_pet.suffix.id}"
  description = "Allow SSH and MLflow UI traffic"

  # Ingress rule for SSH. WARNING: 0.0.0.0/0 is open to the world.
  # For production, you should restrict this to your own IP address.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access from anywhere (for demo purposes)"
  }

  # Ingress rule for MLflow UI
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow MLflow UI access from anywhere"
  }

  # Egress rule to allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "dkakol-mlflow-sg-${random_pet.suffix.id}"
  })
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 4. EC2 Instance to Host the MLflow Server
resource "aws_instance" "mlflow_server" {
  # AMI for Amazon Linux 2 in eu-north-1. You may need to change this
  # if you are using a different AWS region.
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = "t3.micro" # Eligible for the AWS Free Tier
  key_name      = "dkakol-key"

  vpc_security_group_ids = [aws_security_group.mlflow_sg.id]
  iam_instance_profile   = "testEC2Role"

  # This user_data script runs automatically when the instance is first launched.
  # It installs Docker and runs MLflow as a Docker container.
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              usermod -a -G docker ec2-user
              docker run -p 5000:5000 --name mlflow-server -d \
                 ghcr.io/mlflow/mlflow:v2.14.2 mlflow server \
                --host 0.0.0.0 \
                --port 5000 \
                --default-artifact-root s3://${aws_s3_bucket.mlflow_artifacts.bucket}
              EOF

  tags = merge(local.default_tags, {
    Name = "dkakol-MLflow-Server"
  })
}

# 5. Outputs

output "mlflow_server_public_ip" {
  value       = aws_instance.mlflow_server.public_ip
  description = "The public IP address of the MLflow server."
}

output "mlflow_s3_bucket_name" {
  value       = aws_s3_bucket.mlflow_artifacts.bucket
  description = "The name of the S3 bucket used for MLflow artifacts."
}
