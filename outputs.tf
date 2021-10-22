output "alb" {
  description = "ALB endpoint"
  value       = aws_lb.sd_aws_intg_lb.dns_name
}
output "private_subnets" {
  description = "Private Subnets"
  value       = module.vpc.private_subnets
}