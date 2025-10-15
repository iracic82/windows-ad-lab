# ============================================================================
# AWS VPC Module - Outputs
# ============================================================================

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "subnet_id" {
  description = "ID of the created subnet"
  value       = aws_subnet.main.id
}

output "subnet_cidr" {
  description = "CIDR block of the subnet"
  value       = aws_subnet.main.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "route_table_id" {
  description = "ID of the main route table"
  value       = aws_route_table.main.id
}
