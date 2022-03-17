output "private_subnets" {
  description = "Private Subnets"
  value       = module.vpc.private_subnets
}

output "security_group_id" {
  description = "Security Group Id"
  value       = module.securitygroup.security_group_id
}

output "vpc_id" {
  description = "VPC Id"
  value       = module.vpc.id
}

output "route53_zone_name" {
  description = "Route53 Zone Name"
  value       = var.route53_zone_name
}

output "sd_broker_endpointsvc_map" {
  description = "Screwdriver Broker Endpoint Map"
  value       = var.sd_broker_endpointsvc_map
}

output "aws_region" {
  description = "Screwdriver Consumer Region"
  value       = var.aws_region
}