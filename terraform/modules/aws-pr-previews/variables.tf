variable "name" {
  description = "Stack name. Used as a prefix for every resource, the SSM config path and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,19}$", var.name))
    error_message = "Use 1-20 lowercase letters, digits or hyphens, starting with a letter or digit."
  }
}

variable "tags" {
  description = "Extra tags applied to every resource the module creates."
  type        = map(string)
  default     = {}
}

variable "ecr_repositories" {
  description = "Names of ECR repositories to create for application images."
  type        = list(string)
  default     = []
}

variable "ecr_pr_image_expiry_days" {
  description = "Days after which images tagged pr-* are deleted. Untagged images always expire after one day."
  type        = number
  default     = 14

  validation {
    condition     = var.ecr_pr_image_expiry_days >= 1
    error_message = "Must be at least 1 day."
  }
}

variable "log_retention_days" {
  description = "How long preview logs are kept in the shared log group."
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "Must be one of the retention periods CloudWatch Logs accepts: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180 or 365."
  }
}

variable "secret_arns" {
  description = "Extra SSM parameter or Secrets Manager ARNs that preview functions may read, beyond /aws-pr-previews/<name>/*."
  type        = list(string)
  default     = []
}
