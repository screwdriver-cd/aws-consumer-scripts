terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "security_group_prefix" {}
variable "create_sg" {}
variable "vpc_id" {}
variable "build_region" {}
provider "aws" {
  region = var.build_region
}

module "consumer_fn_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.security_group_prefix}-sg"
  description = "Security group for ${var.security_group_prefix} with custom ports open within VPC"
  vpc_id      = var.vpc_id
  create_sg   = var.create_sg
  ingress_with_self = [
    {
      rule = "all-all"
    },
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      description = "Allow all outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}
