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

resource "aws_kms_key" "sd_build_kms_key" {
  description = "KSM Key for Screwdriver Builds"
  enable_key_rotation = true
  policy = <<EOF
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

resource "aws_kms_alias" "sd_build_kms_key_alias" {
  name          = "alias/${var.kms_key_alias_name}"
  target_key_id = aws_kms_key.sd_build_kms_key.key_id
}