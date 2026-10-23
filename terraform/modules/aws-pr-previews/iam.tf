data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "function_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "function" {
  name               = "aws-pr-previews-${var.name}-function"
  assume_role_policy = data.aws_iam_policy_document.function_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "function" {
  statement {
    sid       = "WriteStackLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.previews.arn}:*"]
  }

  statement {
    sid = "ReadStackSecrets"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "secretsmanager:GetSecretValue",
    ]
    resources = concat([
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/aws-pr-previews/${var.name}/*",
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:/aws-pr-previews/${var.name}/*",
    ], var.secret_arns)
  }
}

resource "aws_iam_role_policy" "function" {
  name   = "previews"
  role   = aws_iam_role.function.id
  policy = data.aws_iam_policy_document.function.json
}
