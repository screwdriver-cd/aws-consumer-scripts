locals {
  create_vpc = var.vpc_id == "" ? true : false
  sd_kafka_brokers = [ for b in var.sd_broker_endpointsvc_map: b[0]]
}

data "aws_vpc" "selected" {
  count = local.create_vpc ? 0 : 1
  id    = var.vpc_id
}

data "aws_subnet" "selected" {
  for_each = local.create_vpc ? [] : toset(var.private_subnets)
  vpc_id = var.vpc_id
  cidr_block = each.value
}

locals {
  vpc = (
    local.create_vpc ?
    {
      id              = module.vpc.vpc_id
      cidr_block      = module.vpc.vpc_cidr_block
      private_subnets = module.vpc.private_subnets
    } :
    {
      id              = data.aws_vpc.selected[0].id
      cidr_block      = data.aws_vpc.selected[0].cidr_block
      private_subnets = [for s in data.aws_subnet.selected : s.id]
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
  depends_on        = [module.consumer_fn_sg, aws_route53_zone.sdbrokerprivatezone]
  source            = "./modules/endpoint_interface"
  broker_name       = split(":", each.value[0])[0]
  endpt_svc_name    = each.value[1]
  az_id             = each.key
  subnets           = local.vpc.private_subnets
  vpc_id            = local.vpc.id
  route53_zone_name = var.route53_zone_name
  security_group_id = module.consumer_fn_sg.security_group_id
  tags              = var.tags
}

module "build_artifact_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = var.consumer_bucket_name
  acl    = "private"

  versioning = {
    enabled = false
  }
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name          = var.consumer_fn_name
  description            = "Screwdriver AWS Integration Consumer"
  handler                = "index"
  runtime                = "go1.x"
  create_package         = true
  create_role            = false
  source_path            = "./lambda/"
  vpc_subnet_ids         = local.vpc.private_subnets
  vpc_security_group_ids = [module.consumer_fn_sg.security_group_id]
  memory_size            = "128"
  reserved_concurrent_executions = 5
  timeout                = 300
  lambda_role            = aws_iam_role.sd_consumer_svc_role.arn
  tags                   = var.tags
  cloudwatch_logs_retention_in_days = 7
  cloudwatch_logs_kms_key_id = var.kms_key_arn
  environment_variables = {
    "SD_SLS_BUILD_BUCKET" = "${var.consumer_bucket_name}"
    "SD_SLS_BUILD_ENCRYPTION_KEY" = "${var.kms_key_arn}"
  }
}

resource "aws_lambda_event_source_mapping" "sd_consumer_svc_event_msk" {
  count = var.msk_cluster_arn != "" ? 1 : 0
  event_source_arn  = var.msk_cluster_arn
  function_name     = module.lambda_function.lambda_function_arn
  topics            = [var.kafka_topic]
  starting_position = "TRIM_HORIZON"
  batch_size = 100
  maximum_batching_window_in_seconds = 0
  source_access_configuration {
    type = "SASL_SCRAM_512_AUTH"
    uri  = var.sd_broker_secret_arn
  }
}

resource "aws_lambda_event_source_mapping" "sd_consumer_svc_event" {
  count = var.msk_cluster_arn == "" ? 1 : 0
  depends_on        = [module.lambda_function]
  function_name     = module.lambda_function.lambda_function_arn
  topics            = [var.kafka_topic]
  starting_position = "TRIM_HORIZON"

  self_managed_event_source {
    endpoints = {
      KAFKA_BOOTSTRAP_SERVERS = join(",",local.sd_kafka_brokers)
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
    uri  = "security_group:${module.consumer_fn_sg.security_group_id}"
  }
  source_access_configuration {
    type = "SASL_SCRAM_512_AUTH"
    uri  = var.sd_broker_secret_arn
  }
}

resource "aws_lambda_permission" "allow_ssm" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = module.lambda_function.lambda_function_arn
}
