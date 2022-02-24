terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "create_ecr" {}
variable "ecr_name" {}
variable "consumer_role_arn" {}

resource "aws_ecr_repository" "sd_consumer_ecr" {
  count = var.create_ecr ? 1 : 0
  name                 = var.ecr_name
  image_tag_mutability = "MUTABLE"
}
resource "aws_ecr_repository_policy" "ecrpolicy" {
  depends_on = [
    aws_ecr_repository.sd_consumer_ecr
  ]
  repository = var.ecr_name
  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "codebuildaccessprincipal",
        "Effect": "Allow",
        "Principal": {
          "AWS": "${var.consumer_role_arn}",
          "Service": "codebuild.amazonaws.com"
        },
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetAuthorizationToken"
        ]
      }
    ]
  }
EOF
}
