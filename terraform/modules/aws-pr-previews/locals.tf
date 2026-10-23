locals {
  tags = merge(var.tags, { "pr-previews:stack" = var.name })
}
