terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "build_artifact_bucket" {}
variable "build_role_name" {}
variable "kms_key_alias" {}
variable "create_service_role" {
    type = bool
}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "template_file" "codebuild_assume_role_policy" {
  count = var.create_service_role ? 1 : 0
  template = file("${path.module}/policies/code_build_assume_role_policy.json")
}

data "template_file" "codebuild_base_policy" {
  count = var.create_service_role ? 1 : 0
  template = templatefile("${path.module}/policies/code_build_base_policy.tmpl", {
    aws_account_id = data.aws_caller_identity.current.account_id
    aws_region = data.aws_region.current.name
    build_artifact_bucket = var.build_artifact_bucket
    kms_key_alias = var.kms_key_alias
  })
}
resource "aws_iam_policy" "codebuild_base_policy" {
  count = var.create_service_role ? 1 : 0
  name        = "${var.build_role_name}-CodeBuildBasePolicy"
  description = "CodeBuild Base policy for Screwdriver Builds"
  policy      = data.template_file.codebuild_base_policy[0].rendered
}

# Screwdriver CodeBuild Service Role
resource "aws_iam_role" "sd_build_service_role" {
  count = var.create_service_role ? 1 : 0
  name               = var.build_role_name
  assume_role_policy = data.template_file.codebuild_assume_role_policy[0].rendered
}

resource "aws_iam_role_policy_attachment" "policy-attach1" {
  count = var.create_service_role ? 1 : 0
  role       = aws_iam_role.sd_build_service_role[0].name
  policy_arn = aws_iam_policy.codebuild_base_policy[0].arn
}