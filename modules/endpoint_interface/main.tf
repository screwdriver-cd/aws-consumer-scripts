variable "vpc_id" {}
variable "subnets" { type = map(string)}
variable "vpc_id" {}
variable "tags" {}
variable "broker_name" {}
variable "route53_zone_name" {}
variable "security_group_id" {}

resource "aws_vpc_endpoint" "sd_brkr_service" {
  vpc_id            = var.vpc_id
  service_name      = var.endpt_svc_name
  vpc_endpoint_type = "Interface"

  security_group_ids = [ var.security_group_id ]

  subnet_ids          = [var.subnets]
  private_dns_enabled = false
}

data "aws_route53_zone" "internal" {
  name         = var.route53_zone_name
  private_zone = true
  vpc_id       = var.vpc_id
}

resource "aws_route53_record" "sd_brkr_service_dns" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "${var.broker_name}.${data.aws_route53_zone.internal.name}"
  type    = "A"
  alias {
    name                   = aws_vpc_endpoint.sd_brkr_service.dns_entry[0]["dns_name"]
    zone_id                = aws_vpc_endpoint.sd_brkr_service.dns_entry[0]["hosted_zone_id"]
    evaluate_target_health = true 
  }
}
