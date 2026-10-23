output "ecr_repository_urls" {
  description = "Where to push application images."
  value       = module.previews.ecr_repository_urls
}
