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
