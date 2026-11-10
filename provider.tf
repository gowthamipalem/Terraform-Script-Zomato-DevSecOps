
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for Zomato DevSecOps"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type for DevSecOps tools"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name in the selected region"
  type        = string
}

variable "admin_cidr" {
  description = "Your public IP address with /32 for administrative access"
  type        = string
}

variable "root_volume_size" {
  description = "EC2 root volume size in GB"
  type        = number
  default     = 40
}
