variable "vpc_id" {}
variable "subnets" { type = list(string)}
variable "tags" {}
variable "broker_name" {}
variable "route53_zone_name" {}
variable "security_group_id" {}
variable "endpt_svc_name" {}
variable "az_id" {}


data "aws_subnet" "privatesubnets" {
  for_each = toset(var.subnets)
  id       = each.value
}

locals {
  subnet_az_mapping = { for id, subnet in data.aws_subnet.privatesubnets: format("%s", subnet.availability_zone) => id }
}

resource "aws_vpc_endpoint" "sd_brkr_service" {
  vpc_id            = var.vpc_id
  service_name      = var.endpt_svc_name
  vpc_endpoint_type = "Interface"

  security_group_ids = [ var.security_group_id ]

  subnet_ids          = [lookup(local.subnet_az_mapping, var.az_id)]
  private_dns_enabled = false
  tags = {
    Name = "${var.broker_name}"
  }
}

data "aws_route53_zone" "internal" {
  name         = var.route53_zone_name
  private_zone = true
  vpc_id       = var.vpc_id
}

resource "aws_route53_record" "sd_brkr_service_dns" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = var.broker_name
  type    = "A"
  alias {
    name                   = aws_vpc_endpoint.sd_brkr_service.dns_entry[0]["dns_name"]
    zone_id                = aws_vpc_endpoint.sd_brkr_service.dns_entry[0]["hosted_zone_id"]
    evaluate_target_health = true 
  }
}
