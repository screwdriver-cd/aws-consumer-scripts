variable "route53_zone_name" {}
variable "vpc_id" {}

resource "aws_route53_zone" "sdbrokerprivatezone" {
  name = var.route53_zone_name
  vpc {
    vpc_id = var.vpc_id
  }
}