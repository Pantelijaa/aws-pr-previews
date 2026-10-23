resource "aws_cloudwatch_log_group" "previews" {
  name              = "/aws-pr-previews/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}
