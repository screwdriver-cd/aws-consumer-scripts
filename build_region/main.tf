

module "aws_util" {
  source  = "cloudposse/utils/aws"
  version     = "0.8.1"
}

locals {
  shorten_regions   = true
  naming_convention = local.shorten_regions ? "to_short" : "identity"
  az_map            = module.aws_util.region_az_alt_code_maps[local.naming_convention]
}

module "s3" {
  source        = "../modules/s3"
  bucket_name   = "${var.consumer_bucket_prefix}-${var.user_aws_account_id}-${local.az_map[var.build_region]}"
  build_region  = var.build_region
}

module "vpc_build" {
  source          = "../modules/vpc"
  create_vpc      = var.create_build_vpc && var.build_vpc_id == "" ? true : false
  cidr_block      = var.build_cidr_block
  private_subnets = var.build_private_subnets
  public_subnets  = var.build_public_subnets
  vpc_name        = var.build_vpc_name
  azs             = ["${var.build_region}a", "${var.build_region}b", "${var.build_region}c"]
  vpc_id          = var.build_vpc_id
  tags            = var.tags
  build_region    = var.build_region
}

module "securitygroup_build" {
  source                = "../modules/securitygroup"
  create_sg             = var.create_build_sg
  security_group_prefix = "${var.consumer_fn_name}-build"
  vpc_id                = var.create_build_vpc ? module.vpc_build.id : var.build_vpc_id 
  build_region          = var.build_region
}

module "kms" {
  source             = "../modules/kms"
  kms_key_alias_name = var.sd_build_kms_key_alias
  build_region       = var.build_region
}

moved {
  from = module.kms.aws_kms_key.sd_build_kms_key
  to =  module.kms.aws_kms_key.new_sd_build_kms_key[0]
}

moved {
  from = module.kms.aws_kms_alias.sd_build_kms_key_alias
  to = module.kms.aws_kms_alias.sd_build_kms_key_alias[0]
}