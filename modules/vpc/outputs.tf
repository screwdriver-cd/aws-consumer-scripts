output "id" {
  description = "VPC Id"
  value       = local.vpc.id
}

output "private_subnets" {
  description = "Private Subnets"
  value       = local.vpc.private_subnets
}

output "cidr_block" {
  description = "Cidr Block"
  value       = local.vpc.cidr_block
}