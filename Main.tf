
# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get available subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Find Ubuntu 24.04 AMI dynamically
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "zomato_sg" {
  name        = "zomato-devsecops-sg"
  description = "Security group for Zomato DevSecOps"
  vpc_id      = data.aws_vpc.default.id

  # Zomato application - HTTP
  ingress {
    description = "Zomato application"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access
  ingress {
    description = "SSH administrative access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # Jenkins
  ingress {
    description = "Jenkins dashboard"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # SonarQube
  ingress {
    description = "SonarQube dashboard"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "Zomato-DevSecOps-SG"
    Environment = "DevSecOps"
    Project     = "Zomato"
  }
}

# Zomato DevSecOps EC2 Instance
resource "aws_instance" "zomato_devsecops" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.zomato_sg.id]
  associate_public_ip_address = true

  user_data = file("${path.module}/resource.sh")

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name        = "Zomato-DevSecOps-Server"
    Project     = "Zomato"
    Environment = "DevSecOps"
  }
}

# Outputs
output "zomato_instance_id" {
  value = aws_instance.zomato_devsecops.id
}

output "zomato_public_ip" {
  value = aws_instance.zomato_devsecops.public_ip
}

output "zomato_public_dns" {
  value = aws_instance.zomato_devsecops.public_dns
}
