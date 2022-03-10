
module "aws_util" {
  source  = "cloudposse/utils/aws"
  version     = "0.8.1"
}

locals {
  shorten_regions   = true
  naming_convention = local.shorten_regions ? "to_short" : "identity"
  az_map            = module.aws_util.region_az_alt_code_maps[local.naming_convention]
}

locals {
  sd_kafka_brokers    = [for b in var.sd_broker_endpointsvc_map : b[0]]
}
module "vpc" {
  source          = "./modules/vpc"
  create_vpc      = var.vpc_id == "" ? true : false
  cidr_block      = var.cidr_block
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  vpc_name        = var.vpc_name
  azs             = var.azs
  vpc_id          = var.vpc_id
  tags            = var.tags
  build_region    = var.aws_region
}

module "route53" {
  source            = "./modules/route53"
  route53_zone_name = var.route53_zone_name
  vpc_id            = module.vpc.id
}
module "securitygroup" {
  source                = "./modules/securitygroup"
  security_group_prefix = var.consumer_fn_name
  vpc_id                = module.vpc.id
  create_sg             = true
  build_region          = var.aws_region
}
module "iam" {
  source        = "./modules/iam"
  iam_role_name = var.consumer_fn_name
}

module "lambda" {
  source                   = "./modules/lambda"
  security_group_id        = module.securitygroup.security_group_id
  tags                     = var.tags
  kms_key_arn              = var.kms_key_arn
  consumer_bucket_name     = "${var.consumer_bucket_prefix}-${var.user_aws_account_id}-${local.az_map[var.aws_region]}"
  consumer_fn_name         = var.consumer_fn_name
  sd_consumer_svc_role_arn = module.iam.sd_consumer_svc_role_arn
  private_subnets          = module.vpc.private_subnets
  kms_key_alias            = var.sd_build_kms_key_alias
  kafka_topic              = var.kafka_topic
  msk_cluster_arn          = var.msk_cluster_arn
  log_retention_days       = 7
  sd_kafka_brokers         = local.sd_kafka_brokers
  sd_broker_secret_arn     = var.sd_broker_secret_arn
  build_region             = var.aws_region
}

module "ecr" {
  source                      = "./modules/ecr"
  create_ecr                  = var.create_ecr
  ecr_name                    = var.ecr_name
  consumer_role_arn           = var.consumer_role_arn
  build_region                = var.aws_region
}

module "build_service_role" {
  source                = "./modules/buildrole"
  kms_key_alias         = var.sd_build_kms_key_alias
  build_artifact_bucket = "${var.consumer_bucket_prefix}-${var.user_aws_account_id}-*"
  create_service_role   = var.create_service_role
  build_role_name       = var.build_role_name
}
