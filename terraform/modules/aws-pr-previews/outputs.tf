output "ecr_repository_urls" {
  description = "Repository URL per name in ecr_repositories, for docker tag and push."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}
