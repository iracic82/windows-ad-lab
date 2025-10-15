# ============================================================================
# VPC Peering Module - Connect DC VPC with Client VPC
# ============================================================================

# VPC Peering Connection
resource "aws_vpc_peering_connection" "dc_to_client" {
  vpc_id      = var.dc_vpc_id
  peer_vpc_id = var.client_vpc_id
  auto_accept = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-dc-client-peering"
    }
  )
}

# Get route tables for DC VPC
data "aws_route_tables" "dc_vpc" {
  vpc_id = var.dc_vpc_id
}

# Get route tables for Client VPC
data "aws_route_tables" "client_vpc" {
  vpc_id = var.client_vpc_id
}

# Add routes from DC VPC to Client VPC
resource "aws_route" "dc_to_client" {
  for_each = toset(data.aws_route_tables.dc_vpc.ids)

  route_table_id            = each.key
  destination_cidr_block    = var.client_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.dc_to_client.id
}

# Add routes from Client VPC to DC VPC
resource "aws_route" "client_to_dc" {
  for_each = toset(data.aws_route_tables.client_vpc.ids)

  route_table_id            = each.key
  destination_cidr_block    = var.dc_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.dc_to_client.id
}
