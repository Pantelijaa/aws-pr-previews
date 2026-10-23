# Applied once with local state, which is not committed because the provider
# records the account ID in it. If that state is lost, reattach with:
#   terraform import aws_s3_bucket.state pantelijaa-aws-pr-previews-tfstate
#   terraform import aws_s3_bucket_versioning.state pantelijaa-aws-pr-previews-tfstate
#   terraform import aws_s3_bucket_public_access_block.state pantelijaa-aws-pr-previews-tfstate
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "Region for the state bucket. Every other stack uses the same one."
  type        = string
  default     = "eu-central-1"
}

variable "bucket_name" {
  description = "Globally unique name of the bucket that holds Terraform state."
  type        = string
  default     = "pantelijaa-aws-pr-previews-tfstate"
}

resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket" {
  description = "Name to put in the backend block of every root module."
  value       = aws_s3_bucket.state.bucket
}
