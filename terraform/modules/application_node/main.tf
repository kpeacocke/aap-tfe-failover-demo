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

resource "aws_security_group" "application" {
  name        = "${var.project_prefix}-${var.datacentre_name}-apps"
  description = "Allow demo application traffic only from the shared HAProxy host."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application health and HTTP traffic from HAProxy"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.haproxy_security_group_id]
  }

  egress {
    description = "Operating system package downloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_prefix}-${var.datacentre_name}-apps"
    Project   = "AAP-TFE-Failover-Demo"
    ManagedBy = "Terraform"
    Demo      = "Datacentre-Failover"
  }
}

resource "aws_instance" "application" {
  count = length(var.node_names)

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.application.id]
  associate_public_ip_address = true
  private_ip                  = cidrhost(var.subnet_cidr, 10 + count.index)
  user_data = templatefile("${path.module}/app-user-data.sh.tftpl", {
    app_source  = var.app_source
    datacentre  = var.datacentre_name
    hostname    = var.node_names[count.index]
    app_version = var.application_version
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

  tags = {
    Name       = "${var.project_prefix}-${var.node_names[count.index]}"
    Project    = "AAP-TFE-Failover-Demo"
    ManagedBy  = "Terraform"
    Demo       = "Datacentre-Failover"
    Role       = "application"
    Datacentre = var.datacentre_name
  }
}
