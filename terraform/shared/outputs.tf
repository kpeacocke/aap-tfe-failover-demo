output "vpc_id" {
  description = "ID of the shared demo VPC."
  value       = aws_vpc.demo.id
}

output "project_prefix" {
  description = "Common prefix applied to project-managed resources."
  value       = var.project_prefix
}

output "vpc_cidr_block" {
  description = "CIDR block of the shared demo VPC."
  value       = aws_vpc.demo.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the internet gateway used by the demo subnets."
  value       = aws_internet_gateway.demo.id
}

output "dc1_availability_zone" {
  description = "Availability zone selected for the DC1 subnet."
  value       = aws_subnet.haproxy.availability_zone
}

output "dc2_availability_zone" {
  description = "Second available availability zone selected for the DC2 subnet."
  value       = data.aws_availability_zones.available.names[1]
}

output "dc1_subnet_cidr" {
  description = "CIDR reserved for the DC1 workspace subnet."
  value       = var.dc1_subnet_cidr
}

output "dc2_subnet_cidr" {
  description = "CIDR reserved for the DC2 workspace subnet."
  value       = var.dc2_subnet_cidr
}

output "haproxy_security_group_id" {
  description = "Security group ID used to restrict app ingress to HAProxy."
  value       = aws_security_group.haproxy.id
}

output "frontdoor_public_ip" {
  description = "Stable public IPv4 address for the HAProxy front door."
  value       = aws_eip.haproxy.public_ip
}

output "frontdoor_url" {
  description = "URL for the demo application."
  value       = "http://${aws_eip.haproxy.public_ip}"
}

output "haproxy_private_ip" {
  description = "Private IPv4 address of the HAProxy host."
  value       = aws_instance.haproxy.private_ip
}
