terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

provider "aws" {
  region = var.build_region
}

variable "kms_key_alias_name" {}
variable "build_region" {}

# Retrieve key ID associated with the alias
data "external" "existing_sd_build_kms_key_alias" {
  program = ["bash", "get-kms-key.sh"]

  query = {
    alias = "alias/${var.kms_key_alias_name}"
  }
}

locals {
  existing_sd_build_kms_key_id = trimspace(data.external.existing_sd_build_kms_key_alias.result["key_id"])
}

# Create new KMS key if it doesn't exist
resource "aws_kms_key" "new_sd_build_kms_key" {
  count               = local.existing_sd_build_kms_key_id == "" ? 1 : 0
  description         = "KMS Key for Screwdriver Builds"
  enable_key_rotation = true
  policy              = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "logs.${var.build_region}.amazonaws.com"
                ]
            },
            "Action": [
                "kms:Encrypt*",
                "kms:Decrypt*",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:Describe*"
            ],
            "Resource": "*",
            "Condition": {
                "ArnLike": {
                    "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:*"
                }
            }
        }
    ]
}
EOF
}

# Determine which KMS key to use
locals {
  sd_build_kms_key_id = local.existing_sd_build_kms_key_id != "" ? local.existing_sd_build_kms_key_id : aws_kms_key.new_sd_build_kms_key.*.key_id
}


# Create alias for the KMS key
resource "aws_kms_alias" "sd_build_kms_key_alias" {
  count         = local.existing_sd_build_kms_key_id == "" ? 1 : 0
  name          = "alias/${var.kms_key_alias_name}"
  target_key_id = local.sd_build_kms_key_id
}
