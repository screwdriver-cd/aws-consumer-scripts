output "private_subnets" {
  description = "Private Subnets"
  value       = module.vpc_build.private_subnets
}

output "security_group_id" {
  description = "Security Group Id"
  value       = module.securitygroup_build.security_group_id
}

output "vpc_id" {
  description = "VPC Id"
  value       = module.vpc_build.id
}

output "sd_broker_endpointsvc_map" {
  description = "Screwdriver Broker Endpoint Map"
  value       = var.sd_broker_endpointsvc_map
}

output "build_region" {
  description = "Screwdriver Consumer Build Region"
  value       = var.build_region
}