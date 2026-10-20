variable "aws_region" {
  description = "Verified AWS region of the existing RHDP lab; no default is assumed."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.aws_region))
    error_message = "Set aws_region to the verified AWS region code of the RHDP lab."
  }
}

variable "project_prefix" {
  description = "Prefix applied to demo-managed AWS resource names."
  type        = string
  default     = "ww-demo"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,23}$", var.project_prefix))
    error_message = "project_prefix must be 3 to 24 lowercase letters, digits, or hyphens and start with a letter or digit."
  }
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
  description = "Optional existing EC2 key pair; omit to register the supplied public key."
  type        = string
  default     = null

  validation {
    condition     = var.ssh_key_pair_name == null || try(length(trimspace(var.ssh_key_pair_name)) > 0, false)
    error_message = "Omit ssh_key_pair_name for a managed key pair, rather than setting it to an empty string."
  }
}

variable "ssh_public_key" {
  description = "OpenSSH public key to register with AWS; never supply the private key."
  type        = string
  default     = null

  validation {
    condition     = var.ssh_public_key == null || can(regex("^(ssh-ed25519|ssh-rsa) [A-Za-z0-9+/=]+( .*)?$", trimspace(var.ssh_public_key)))
    error_message = "ssh_public_key must be an OpenSSH RSA or Ed25519 public key."
  }
}

variable "admin_cidr" {
  description = "IPv4 CIDR allowed to SSH to HAProxy, preferably the presenter's /32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "admin_cidr must be a valid IPv4 CIDR block."
  }
}

variable "aap_ssh_cidr" {
  description = "Optional verified AAP execution-pod IPv4 egress /32 for HAProxy SSH only."
  type        = string
  default     = null

  validation {
    condition     = var.aap_ssh_cidr == null || (can(cidrnetmask(var.aap_ssh_cidr)) && can(regex("/32$", var.aap_ssh_cidr)))
    error_message = "aap_ssh_cidr must be a valid IPv4 /32, not a broad subnet."
  }
}
