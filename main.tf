locals {
  for_each         = var.sd_broker_endpointsvc_map
  sd_kafka_brokers = concat(each[0])
}
locals {
  create_vpc = var.vpc_id != null ? true : false
}

data "aws_vpc" "selected" {
  count = local.create_vpc ? 0 : 1

  id = var.vpc_id
  private_subnets = var.private_subnets
}

locals {
  vpc = (
    local.create_vpc ?
    {
      id         = module.vpc.vpc_id
      cidr_block = module.vpc.cidr_block
      private_subnets = module.vpc.private_subnets
    } :
    {
      id         = data.aws_vpc.selected.id
      cidr_block = data.aws_vpc.selected.cidr_block
      private_subnets = data.aws_vpc.selected.private_subnets
    }
  )
}

module "consumer_fn_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.consumer_fn_name}-sg"
  description = "Security group for ${var.consumer_fn_name} with custom ports open within VPC"
  vpc_id      = local.vpc.id

  ingress_with_self = [
    {
      rule = "all-all"
    },
  ]
}
resource "aws_route53_zone" "sdbrokerprivatezone" {
  name = var.route53_zone_name
  vpc {
    vpc_id = local.vpc.id
  }
}
data "template_file" "assume_role_policy" {
  template = file("policies/lambda_assume_role_policy.json")
}
data "template_file" "lambda_vpc_policy" {
  template = file("policies/lambda_vpc_access_policy.json")
}
data "template_file" "lambda_msk_policy" {
  template = file("policies/lambda_msk_access_policy.json")
}
data "template_file" "lambda_cb_policy" {
  template = file("policies/lambda_codebuild_policy.json")
}

resource "aws_iam_role" "sd_consumer_svc_role" {
  name               = var.consumer_fn_name
  assume_role_policy = data.template_file.assume_role_policy.rendered
}

resource "aws_iam_policy" "lambda_vpc_policy" {
  name        = "${var.consumer_fn_name}VPCAccess"
  description = "VPC access policy for consumer fn"
  policy      = data.template_file.lambda_vpc_policy.rendered
}

resource "aws_iam_policy" "lambda_msk_policy" {
  name        = "${var.consumer_fn_name}MSKExecutionAccess"
  description = "MSK execution access policy for consumer fn"
  policy      = data.template_file.lambda_msk_policy.rendered
}

resource "aws_iam_policy" "lambda_cb_policy" {
  name        = "${var.consumer_fn_name}CodeBuildAccess"
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

module "endpoint_interface" {
  for_each          = var.sd_broker_endpointsvc_map
  depends_on        = [aws_route53_zone.sdbrokerprivatezone]
  source            = "./modules/endpoint_interface"
  broker_name       = each.value[0]
  endpt_svc_name    = each.value[1]
  subnets           = local.vpc.private_subnets
  vpc_id            = local.vpc.id
  route53_zone_name = var.route53_zone_name
  security_group_id = module.consumer_fn_sg.id
  tags              = var.tags
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name          = var.consumer_fn_name
  description            = "Screwdriver AWS Integration Consumer"
  handler                = "index"
  runtime                = "go1.x"
  create_package         = true
  source_path            = "./aws-consumer-service/"
  vpc_subnet_ids         = local.vpc.private_subnets
  vpc_security_group_ids = [module.consumer_fn_sg.id]
  memory_size            = "128"
  concurrency            = "5"
  lambda_timeout         = "300"
  role_arn               = aws_iam_role.sd_consumer_svc_role.role_arn
  tags                   = var.tags
}

resource "aws_lambda_event_source_mapping" "sd_consumer_svc_event" {
  depends_on        = [module.lambda_function]
  function_name     = module.lambda_function.arn
  topics            = [var.kafka_topic]
  starting_position = "TRIM_HORIZON"

  self_managed_event_source {
    endpoints = {
      KAFKA_BOOTSTRAP_SERVERS = local.sd_kafka_brokers
    }
  }
  source_access_configuration {
    type = "VPC_SUBNET"
    uri  = "subnet:${local.vpc.private_subnets[0]}"
  }
  source_access_configuration {
    type = "VPC_SUBNET"
    uri  = "subnet:${local.vpc.private_subnets[1]}"
  }
  source_access_configuration {
    type = "VPC_SUBNET"
    uri  = "subnet:${local.vpc.private_subnets[2]}"
  }
  source_access_configuration {
    type = "VPC_SECURITY_GROUP"
    uri  = "security_group:${module.consumer_fn_sg.id}"
  }
  source_access_configuration {
    type = "SASL_SCRAM_512_AUTH"
    uri  = var.sd_broker_secret_arn
  }
}

resource "aws_lambda_permission" "allow_ssm" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.name
  principal     = "secretsmanager.amazonaws.com"
}

