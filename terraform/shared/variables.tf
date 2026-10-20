variable "project_prefix" {
  description = "Prefix applied to demo-managed AWS resource names."
  type        = string
  default     = "ww-demo"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,23}$", var.project_prefix))
    error_message = "project_prefix must be 3 to 24 lowercase letters, digits, or hyphens and start with a letter or digit."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the demo VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "haproxy_subnet_cidr" {
  description = "Public subnet CIDR for the HAProxy host."
  type        = string
  default     = "10.20.0.0/24"

  validation {
    condition     = can(cidrnetmask(var.haproxy_subnet_cidr))
    error_message = "haproxy_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "dc1_subnet_cidr" {
  description = "Public subnet CIDR reserved for the DC1 workspace."
  type        = string
  default     = "10.20.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.dc1_subnet_cidr))
    error_message = "dc1_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "dc2_subnet_cidr" {
  description = "Public subnet CIDR reserved for the DC2 workspace."
  type        = string
  default     = "10.20.2.0/24"

  validation {
    condition     = can(cidrnetmask(var.dc2_subnet_cidr))
    error_message = "dc2_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the HAProxy host."
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_pair_name" {
  description = "Name of an existing EC2 key pair used for restricted HAProxy administration."
  type        = string
}

variable "admin_cidr" {
  description = "IPv4 CIDR allowed to SSH to HAProxy, preferably the presenter's /32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "admin_cidr must be a valid IPv4 CIDR block."
  }
}
