# ============================================================================
# Security Groups Module - Outputs
# ============================================================================

output "dc_sg_id" {
  description = "Domain Controllers security group ID"
  value       = aws_security_group.domain_controllers.id
}

output "client_sg_id" {
  description = "Domain Clients security group ID"
  value       = aws_security_group.domain_clients.id
}

output "dc_sg_name" {
  description = "Domain Controllers security group name"
  value       = aws_security_group.domain_controllers.name
}

output "client_sg_name" {
  description = "Domain Clients security group name"
  value       = aws_security_group.domain_clients.name
}
