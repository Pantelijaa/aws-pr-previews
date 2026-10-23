output "ecr_repository_urls" {
  description = "Repository URL per name in ecr_repositories, for docker tag and push."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "function_role_arn" {
  description = "Execution role every preview function runs as."
  value       = aws_iam_role.function.arn
}

output "log_group_name" {
  description = "Shared log group all preview functions write to."
  value       = aws_cloudwatch_log_group.previews.name
}
