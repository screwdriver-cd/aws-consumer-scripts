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

variable "bucket_name" {}
variable "build_region" {}


module "aws_util" {
  source  = "cloudposse/utils/aws"
  version     = "1.4.0"
}

locals {
  shorten_regions   = true
  naming_convention = local.shorten_regions ? "to_short" : "identity"
  az_map            = module.aws_util.region_az_alt_code_maps[local.naming_convention]
  region_suffix     = local.az_map[var.build_region]
}

module "build_artifact_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  bucket = var.bucket_name
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = false
  }
}
