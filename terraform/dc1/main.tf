provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Project   = "AAP-TFE-Failover-Demo"
      ManagedBy = "Terraform"
      Demo      = "Woolworths"
    }
  }
}

data "terraform_remote_state" "shared" {
  backend = "remote"

  config = {
    hostname     = "app.terraform.io"
    organization = var.terraform_organization

    workspaces = {
      name = "ww-demo-shared"
    }
  }
}

resource "aws_subnet" "dc1" {
  vpc_id                  = data.terraform_remote_state.shared.outputs.vpc_id
  cidr_block              = data.terraform_remote_state.shared.outputs.dc1_subnet_cidr
  availability_zone       = data.terraform_remote_state.shared.outputs.dc1_availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name       = "${data.terraform_remote_state.shared.outputs.project_prefix}-dc1-subnet"
    Project    = "AAP-TFE-Failover-Demo"
    ManagedBy  = "Terraform"
    Demo       = "Woolworths"
    Datacentre = "dc1"
  }
}

resource "aws_route_table" "dc1" {
  vpc_id = data.terraform_remote_state.shared.outputs.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.terraform_remote_state.shared.outputs.internet_gateway_id
  }

  tags = {
    Name      = "${data.terraform_remote_state.shared.outputs.project_prefix}-dc1-public"
    Project   = "AAP-TFE-Failover-Demo"
    ManagedBy = "Terraform"
    Demo      = "Woolworths"
  }
}

resource "aws_route_table_association" "dc1" {
  subnet_id      = aws_subnet.dc1.id
  route_table_id = aws_route_table.dc1.id
}

module "application" {
  source = "../modules/application_node"

  project_prefix            = data.terraform_remote_state.shared.outputs.project_prefix
  datacentre_name           = "dc1"
  node_names                = ["dc1-app-01", "dc1-app-02"]
  application_version       = var.application_version
  instance_type             = var.instance_type
  vpc_id                    = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_id                 = aws_subnet.dc1.id
  subnet_cidr               = data.terraform_remote_state.shared.outputs.dc1_subnet_cidr
  haproxy_security_group_id = data.terraform_remote_state.shared.outputs.haproxy_security_group_id
  app_source                = file("${path.module}/../../application/app.py")

  depends_on = [aws_route_table_association.dc1]
}

output "datacentre_name" {
  description = "Datacentre identifier managed by this workspace."
  value       = "dc1"
}

output "application_private_ips" {
  description = "Private IPv4 addresses of the DC1 application nodes."
  value       = module.application.private_ips
}

output "application_public_ips" {
  description = "Public IPv4 addresses of the DC1 application nodes."
  value       = module.application.public_ips
}

output "application_instance_ids" {
  description = "EC2 instance IDs of the DC1 application nodes."
  value       = module.application.instance_ids
}

output "health_urls" {
  description = "Private health endpoint URLs for the DC1 application nodes."
  value       = formatlist("http://%s:8080/health", module.application.private_ips)
}
