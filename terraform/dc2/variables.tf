variable "aws_region" {
  description = "Verified AWS region of the existing RHDP lab; must match the shared workspace."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "Set aws_region to the verified AWS region code of the RHDP lab."
  }
}

variable "terraform_organization" {
  description = "HCP Terraform organization containing the shared workspace."
  type        = string
}

variable "aws_account_id" {
  description = "Optional AWS account ID Terraform is allowed to manage."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.aws_account_id == null || can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID when set."
  }
}

variable "instance_type" {
  description = "EC2 instance type for each application node."
  type        = string
  default     = "t3.micro"
}

variable "application_version" {
  description = "Version displayed by the demo application."
  type        = string
  default     = "1.0.0"
}
