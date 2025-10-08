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
  region = "eu-north-1" 
}

resource "random_pet" "suffix" {
  length = 2
}

# common tags
locals {
  default_tags = {
    Owner   = "dkakol"
    Project = "ml/mlops-internship"
  }
}

# mlflow artifact store
resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket = "dkakol-mlflow-artifacts-${random_pet.suffix.id}"
  force_destroy = true
  tags = merge(local.default_tags, {
    Name = "dkakol-mlflow-artifacts-${random_pet.suffix.id}"
  })
}

# 3. Security Group for the EC2 Instance
resource "aws_security_group" "mlflow_sg" {
  name        = "dkakol-mlflow-sg-${random_pet.suffix.id}"
  description = "Allow SSH and MLflow UI traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access from anywhere (for demo purposes)"
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow MLflow UI access from anywhere"
  }


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
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = "t3.micro" 
  key_name      = "dkakol-key"

  vpc_security_group_ids = [aws_security_group.mlflow_sg.id]
  iam_instance_profile   = "testEC2Role"

  # Mlflow setup on ec2
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

resource "aws_s3_bucket_lifecycle_configuration" "mlflow_artifacts_lifecycle" {
  bucket = aws_s3_bucket.mlflow_artifacts.id

  rule {
    id     = "auto-delete-after-3-days"
    status = "Enabled"
    filter {}
    expiration {
      days = 3
    }
  }
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
