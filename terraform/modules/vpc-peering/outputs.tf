# ============================================================================
# VPC Peering Module - Outputs
# ============================================================================

output "peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.dc_to_client.id
}

output "peering_status" {
  description = "Status of the VPC peering connection"
  value       = aws_vpc_peering_connection.dc_to_client.accept_status
}
