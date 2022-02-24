output "build_role_arn" {
    value = aws_iam_role.sd_build_service_role[*].arn
}