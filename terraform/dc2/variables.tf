variable "terraform_organization" {
  description = "HCP Terraform organization containing the shared workspace."
  type        = string
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
