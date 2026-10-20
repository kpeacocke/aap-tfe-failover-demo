output "security_group_id" {
  description = "Security group ID for this datacentre's application nodes."
  value       = aws_security_group.application.id
}

output "private_ips" {
  description = "Private IPv4 addresses of the application nodes."
  value       = aws_instance.application[*].private_ip
}

output "public_ips" {
  description = "Public IPv4 addresses used for operating system package downloads."
  value       = aws_instance.application[*].public_ip
}

output "instance_ids" {
  description = "EC2 instance IDs for this datacentre's application nodes."
  value       = aws_instance.application[*].id
}
