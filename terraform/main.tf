terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# SSH Key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "n8n" {
  key_name   = "n8n-deploy-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/n8n-key.pem"
  file_permission = "0600"
}

# Security Group
resource "aws_security_group" "n8n" {
  name        = "n8n-instance"
  description = "n8n single instance"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP for ACME"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "n8n" {
  ami           = "ami-0030e4319cbf4dbf2"
  instance_type = "t3.small"

  key_name               = aws_key_pair.n8n.key_name
  vpc_security_group_ids = [aws_security_group.n8n.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y ca-certificates curl

              # Install Docker
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              chmod a+r /etc/apt/keyrings/docker.asc
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
              usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker

              # Create n8n data directory
              mkdir -p /home/ubuntu/n8n-data
              chown -R ubuntu:ubuntu /home/ubuntu/n8n-data
              EOF

  tags = {
    Name    = "n8n-instance"
    Project = "n8n-deploy"
  }
}

# Outputs
output "n8n_ip" {
  description = "Public IP of n8n instance"
  value       = aws_instance.n8n.public_ip
}

output "n8n_url" {
  description = "n8n access URL"
  value       = "https://n8n.bghub.cc"
}

output "ssh_command" {
  description = "SSH command"
  value       = "ssh -i n8n-key.pem ubuntu@${aws_instance.n8n.public_ip}"
}
