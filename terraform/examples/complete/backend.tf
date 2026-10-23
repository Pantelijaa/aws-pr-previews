terraform {
  # Backend blocks cannot read variables, so the bucket and region are literal here.
  backend "s3" {
    bucket       = "pantelijaa-aws-pr-previews-tfstate"
    key          = "main/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}
