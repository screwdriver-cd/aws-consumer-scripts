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
}
module "iam" {
  source        = "./modules/iam"
  iam_role_name = var.consumer_fn_name
}
module "s3" {
  providers = {
    aws = aws.build
  }
  source      = "./modules/s3"
  bucket_name = var.consumer_bucket_name
}

module "lambda" {
  source                   = "./modules/lambda"
  security_group_id        = module.securitygroup.security_group_id
  tags                     = var.tags
  kms_key_arn              = var.kms_key_arn
  consumer_bucket_name     = var.consumer_bucket_name
  consumer_fn_name         = var.consumer_fn_name
  sd_consumer_svc_role_arn = module.iam.sd_consumer_svc_role_arn
  private_subnets          = module.vpc.private_subnets
  kms_key_alias            = var.sd_build_kms_key_alias
  kafka_topic              = var.kafka_topic
  msk_cluster_arn          = var.msk_cluster_arn
  log_retention_days       = 7
  sd_kafka_brokers         = local.sd_kafka_brokers
  sd_broker_secret_arn     = var.sd_broker_secret_arn
}

module "ecr" {
  providers = {
    aws = aws.build
  }
  source                      = "./modules/ecr"
  create_ecr                  = var.create_ecr
  ecr_name                    = var.ecr_name
  consumer_role_arn           = var.consumer_role_arn
}

# If builds are running in region other than the consumer service region 
# additionally create vpc, security group, ecr
module "vpc_build" {
  providers = {
    aws = aws.build
  }
  source          = "./modules/vpc"
  create_vpc      = var.create_build_vpc && var.build_vpc_id == "" ? true : false
  cidr_block      = var.build_cidr_block
  private_subnets = var.build_private_subnets
  public_subnets  = var.build_public_subnets
  vpc_name        = var.build_vpc_name
  azs             = var.build_azs
  vpc_id          = var.build_vpc_id
  tags            = var.tags
}

module "securitygroup_build" {
  providers = {
    aws = aws.build
  }
  source                = "./modules/securitygroup"
  create_sg             = var.create_build_vpc
  security_group_prefix = "${var.consumer_fn_name}-build"
  vpc_id                = module.vpc_build.id
}

module "kms" {
  providers = {
    aws = aws.build
  }
  source             = "./modules/kms"
  kms_key_alias_name = var.sd_build_kms_key_alias
}
