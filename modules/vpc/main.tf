terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.build_region
}

variable "private_subnets" {}
variable "public_subnets" {}
variable "vpc_id" {}
variable "cidr_block" {}
variable "vpc_name" {}
variable "azs" {}
variable "create_vpc" {}
variable "tags" {}
variable "build_region" {}

data "aws_vpc" "selected" {
  count = var.create_vpc ? 0 : 1
  id    = var.vpc_id
}

data "aws_subnets" "selected" {
  count = var.create_vpc ? 0 : 1
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Network = "Private"
  }
}

locals {
  vpc = (
    var.create_vpc ?
    {
      id              = module.vpc.vpc_id
      cidr_block      = module.vpc.vpc_cidr_block
      private_subnets = module.vpc.private_subnets
    } :
    {
      id              = data.aws_vpc.selected[0].id
      cidr_block      = data.aws_vpc.selected[0].cidr_block
      private_subnets = data.aws_subnets.selected[0].ids
    }
  )
}

locals {
  network_acls = {
    default_inbound = [
      {
        rule_number = 900
        rule_action = "allow"
        from_port   = 1024
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    default_outbound = [
      {
        rule_number = 900
        rule_action = "allow"
        from_port   = 1024
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    public_inbound = [
      {
        rule_number = 1000
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "${var.cidr_block}"
      },
      {
        rule_number = 1100
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "${var.cidr_block}"
      },
      {
        rule_number = 1200
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = "${var.cidr_block}"
      }
    ]
    public_outbound = [
      {
        rule_number = 1000
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 1100
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 1200
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
    private_inbound = [
      {
        rule_number = 1000
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "${var.cidr_block}"
      },
      {
        rule_number = 1100
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "${var.cidr_block}"
      },
      {
        rule_number = 1200
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = "${var.cidr_block}"
      }
    ]
    private_outbound = [
      {
        rule_number = 1000
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 1100
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 1200
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
  }
}

module "vpc" {
  source     = "terraform-aws-modules/vpc/aws"
  create_vpc = var.create_vpc

  name = var.vpc_name
  cidr = var.cidr_block

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  manage_default_network_acl    = false
  public_dedicated_network_acl  = true
  public_inbound_acl_rules      = concat(local.network_acls["default_inbound"], local.network_acls["public_inbound"])
  public_outbound_acl_rules     = concat(local.network_acls["default_outbound"], local.network_acls["public_outbound"])
  private_dedicated_network_acl = true
  private_inbound_acl_rules     = concat(local.network_acls["default_inbound"], local.network_acls["private_inbound"])
  private_outbound_acl_rules    = concat(local.network_acls["default_outbound"], local.network_acls["private_outbound"])

  tags = var.tags
  private_subnet_tags = merge(tomap("${var.tags}"),
    { Network : "Private" }
  )
  public_subnet_tags = merge(tomap("${var.tags}"),
    { Network : "Public" }
  )
}
