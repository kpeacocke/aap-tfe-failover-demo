terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  backend "remote" {
    hostname = "app.terraform.io"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
