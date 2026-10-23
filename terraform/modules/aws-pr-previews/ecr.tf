resource "aws_ecr_repository" "this" {
  for_each = toset(var.ecr_repositories)

  name = each.value
  # Lets terraform destroy remove a repository that still holds images.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after a day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire pr-* images after ${var.ecr_pr_image_expiry_days} days"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["pr-"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = var.ecr_pr_image_expiry_days
        }
        action = { type = "expire" }
      }
    ]
  })
}
