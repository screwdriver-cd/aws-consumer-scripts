terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "bucket_name" {}

module "build_artifact_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  bucket = var.bucket_name
  acl    = "private"
  versioning = {
    enabled = false
  }
}