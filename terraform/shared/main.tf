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

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  tags = {
    Project   = "AAP-TFE-Failover-Demo"
    ManagedBy = "Terraform"
    Demo      = "Woolworths"
  }

  dc1_app_ips = [
    cidrhost(var.dc1_subnet_cidr, 10),
    cidrhost(var.dc1_subnet_cidr, 11),
  ]
  dc2_app_ips = [
    cidrhost(var.dc2_subnet_cidr, 10),
    cidrhost(var.dc2_subnet_cidr, 11),
  ]
}

resource "aws_vpc" "demo" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${var.project_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id

  tags = merge(local.tags, {
    Name = "${var.project_prefix}-igw"
  })
}

resource "aws_subnet" "haproxy" {
  vpc_id                  = aws_vpc.demo.id
  cidr_block              = var.haproxy_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${var.project_prefix}-haproxy-subnet"
    Role = "shared"
  })
}

resource "aws_route_table" "haproxy" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }

  tags = merge(local.tags, {
    Name = "${var.project_prefix}-haproxy-public"
  })
}

resource "aws_route_table_association" "haproxy" {
  subnet_id      = aws_subnet.haproxy.id
  route_table_id = aws_route_table.haproxy.id
}

resource "aws_security_group" "haproxy" {
  name        = "${var.project_prefix}-haproxy"
  description = "Demo front door; HTTP from the internet and SSH from the admin CIDR."
  vpc_id      = aws_vpc.demo.id

  ingress {
    description = "Demo application front door"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Restricted administrator access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "HAProxy health checks to application nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.project_prefix}-haproxy"
  })
}

resource "aws_instance" "haproxy" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.haproxy.id
  vpc_security_group_ids      = [aws_security_group.haproxy.id]
  key_name                    = var.ssh_key_pair_name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/haproxy-user-data.sh.tftpl", {
    haproxy_config = templatefile("${path.module}/haproxy.cfg.tftpl", {
      dc1_app_ips = local.dc1_app_ips
      dc2_app_ips = local.dc2_app_ips
    })
    dc1_app_ip_1  = local.dc1_app_ips[0]
    dc1_app_ip_2  = local.dc1_app_ips[1]
    dc2_app_ip_1  = local.dc2_app_ips[0]
    dc2_app_ip_2  = local.dc2_app_ips[1]
    switch_script = file("${path.module}/set-active-datacentre.sh")
  })
  user_data_replace_on_change = true

  root_block_device {
    encrypted             = true
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.tags, {
    Name = "${var.project_prefix}-haproxy"
    Role = "frontdoor"
  })

  depends_on = [aws_route_table_association.haproxy]
}

resource "aws_eip" "haproxy" {
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${var.project_prefix}-frontdoor"
  })
}

resource "aws_eip_association" "haproxy" {
  allocation_id = aws_eip.haproxy.id
  instance_id   = aws_instance.haproxy.id
}
