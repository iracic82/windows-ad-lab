# ============================================================================
# Windows Instance Module - Outputs
# ============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.instance.id
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_network_interface.eni.private_ip
}

output "public_ip" {
  description = "Public IP address (EIP)"
  value       = var.create_eip ? aws_eip.eip[0].public_ip : null
}

output "eni_id" {
  description = "Network interface ID"
  value       = aws_network_interface.eni.id
}

output "name" {
  description = "Instance name"
  value       = var.name
}

output "role" {
  description = "Instance role"
  value       = var.role
}
