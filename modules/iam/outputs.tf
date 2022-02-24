
output "sd_consumer_svc_role_arn" {
  description = "IAM Role Arn"
  value       = aws_iam_role.sd_consumer_svc_role.arn
}
