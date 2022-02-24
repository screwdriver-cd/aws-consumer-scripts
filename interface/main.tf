variable "security_group_id" {}
variable "private_subnets" {}
variable "vpc_id" {}
variable "route53_zone_name" {}
variable "sd_broker_endpointsvc_map" {}
variable "aws_region" {}
variable "tags" {
  type = map(string)
  default = {
    PRODUCT : "SCREWDRIVER"
    ENVIRONMENT : "prod"
    TYPE: "endpoint-interface"
    SERVICE : "screwdriver/consumer"
  }
}

module "endpoint_interface" {
  for_each          = var.sd_broker_endpointsvc_map
  source            = "./modules/endpoint_interface"
  broker_name       = split(":", each.value[0])[0]
  endpt_svc_name    = each.value[1]
  az_id             = each.key
  subnets           = var.private_subnets
  vpc_id            = var.vpc_id
  route53_zone_name = var.route53_zone_name
  security_group_id = var.security_group_id
  tags              = var.tags
}
