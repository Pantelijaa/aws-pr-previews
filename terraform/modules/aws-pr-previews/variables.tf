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
