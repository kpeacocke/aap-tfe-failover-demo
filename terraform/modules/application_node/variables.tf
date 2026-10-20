variable "project_prefix" {
  description = "Prefix used for demo resource names."
  type        = string
}

variable "datacentre_name" {
  description = "Datacentre identifier returned by the application."
  type        = string
}

variable "node_names" {
  description = "Stable application hostnames for this datacentre."
  type        = list(string)
}

variable "application_version" {
  description = "Version displayed by the demo application."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._+-]{0,31}$", var.application_version))
    error_message = "application_version must be 1 to 32 letters, digits, dots, underscores, plus signs, or hyphens."
  }
}

variable "instance_type" {
  description = "EC2 instance type used for application nodes."
  type        = string
}

variable "vpc_id" {
  description = "ID of the shared VPC."
  type        = string
}

variable "subnet_id" {
  description = "ID of this datacentre's subnet."
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block used to assign stable private IP addresses."
  type        = string
}

variable "haproxy_security_group_id" {
  description = "ID of the shared HAProxy security group."
  type        = string
}

variable "app_source" {
  description = "Contents of the standard-library demo application."
  type        = string
}
