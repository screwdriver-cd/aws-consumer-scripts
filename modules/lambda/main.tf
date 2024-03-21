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

variable "build_region" {}

variable "consumer_bucket_name" {}
variable "consumer_fn_name" {}
variable "security_group_id" {}
variable "sd_consumer_svc_role_arn" {}
variable "private_subnets" {}
variable "kms_key_arn" {}
variable "kms_key_alias" {}
variable "log_retention_days" {}
variable "tags" {}
variable "kafka_topic" {}
variable "msk_cluster_arn" {}
variable "sd_kafka_brokers" {}
variable "sd_broker_secret_arn" {}


module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name          = var.consumer_fn_name
  description            = "Screwdriver AWS Integration Consumer"
  handler                = "bootstrap"
  runtime                = "provided.al2023"
  create_package         = true
  create_role            = false
  source_path            = "./lambda/bootstrap"
  vpc_subnet_ids         = var.private_subnets
  vpc_security_group_ids = [var.security_group_id]
  memory_size            = "128"
  reserved_concurrent_executions = 5
  timeout                = 300
  lambda_role            = var.sd_consumer_svc_role_arn
  tags                   = var.tags
  cloudwatch_logs_retention_in_days = var.log_retention_days
  cloudwatch_logs_kms_key_id = var.kms_key_arn
  environment_variables = {
    "SD_SLS_BUILD_BUCKET" = "${var.consumer_bucket_name}"
    "SD_SLS_BUILD_ENCRYPTION_KEY_ALIAS" = "alias/${var.kms_key_alias}"
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
      KAFKA_BOOTSTRAP_SERVERS = join(",",var.sd_kafka_brokers)
    }
  }
  source_access_configuration {
    type = "VPC_SUBNET"
    uri  = "subnet:${var.private_subnets[0]}"
  }
  source_access_configuration {
    type = "VPC_SUBNET"
    uri  = "subnet:${var.private_subnets[1]}"
  }
  source_access_configuration {
    type = "VPC_SUBNET"
    uri  = "subnet:${var.private_subnets[2]}"
  }
  source_access_configuration {
    type = "VPC_SECURITY_GROUP"
    uri  = "security_group:${var.security_group_id}"
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
