terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "iam_role_name" {}

data "template_file" "assume_role_policy" {
  template = file("${path.root}/policies/lambda_assume_role_policy.json")
}
data "template_file" "lambda_vpc_policy" {
  template = file("${path.root}/policies/lambda_vpc_access_policy.json")
}
data "template_file" "lambda_msk_policy" {
  template = file("${path.root}/policies/lambda_msk_access_policy.json")
}
data "template_file" "lambda_cb_policy" {
  template = file("${path.root}/policies/lambda_codebuild_policy.json")
}

resource "aws_iam_role" "sd_consumer_svc_role" {
  name               = var.iam_role_name
  assume_role_policy = data.template_file.assume_role_policy.rendered
}

resource "aws_iam_policy" "lambda_vpc_policy" {
  name        = "${var.iam_role_name}VPCAccess"
  description = "VPC access policy for consumer fn"
  policy      = data.template_file.lambda_vpc_policy.rendered
}

resource "aws_iam_policy" "lambda_msk_policy" {
  name        = "${var.iam_role_name}MSKExecutionAccess"
  description = "MSK execution access policy for consumer fn"
  policy      = data.template_file.lambda_msk_policy.rendered
}

resource "aws_iam_policy" "lambda_cb_policy" {
  name        = "${var.iam_role_name}CodeBuildAccess"
  description = "CodeBuild access policy for consumer fn"
  policy      = data.template_file.lambda_cb_policy.rendered
}

resource "aws_iam_role_policy_attachment" "policy-attach1" {
  role       = aws_iam_role.sd_consumer_svc_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy.arn
}
resource "aws_iam_role_policy_attachment" "policy-attach2" {
  role       = aws_iam_role.sd_consumer_svc_role.name
  policy_arn = aws_iam_policy.lambda_msk_policy.arn
}

resource "aws_iam_role_policy_attachment" "policy-attach3" {
  role       = aws_iam_role.sd_consumer_svc_role.name
  policy_arn = aws_iam_policy.lambda_cb_policy.arn
}