module "previews" {
  source = "../../modules/aws-pr-previews"

  name             = "main"
  ecr_repositories = ["demo-app"]
}
