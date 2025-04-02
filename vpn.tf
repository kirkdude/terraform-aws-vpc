################################################################################
# Customer Gateway
################################################################################

resource "aws_customer_gateway" "this" {
  for_each = { for k, v in var.customer_gateways : k => v if local.create_vpc }

  bgp_asn     = each.value["bgp_asn"]
  ip_address  = each.value["ip_address"]
  device_name = lookup(each.value, "device_name", null)
  type        = "ipsec.1"

  tags = merge(
    { Name = "${var.name}-${each.key}" },
    var.tags,
    var.customer_gateway_tags,
  )
}

################################################################################
# VPN Gateway
################################################################################

resource "aws_vpn_gateway" "this" {
  count = local.create_vpc && var.enable_vpn_gateway ? 1 : 0

  vpc_id            = local.vpc_id
  amazon_side_asn   = var.amazon_side_asn
  availability_zone = var.vpn_gateway_az

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.vpn_gateway_tags,
  )
}

resource "aws_vpn_gateway_attachment" "this" {
  count = var.vpn_gateway_id != null && local.create_vpc ? 1 : 0

  vpc_id         = local.vpc_id
  vpn_gateway_id = var.vpn_gateway_id
}

resource "aws_vpn_gateway_route_propagation" "public" {
  count = local.create_vpc && var.enable_vpn_gateway && local.create_public_subnets ? local.num_public_route_tables : 0

  route_table_id = element(aws_route_table.public[*].id, count.index)
  vpn_gateway_id = element(
    concat(
      aws_vpn_gateway.this[*].id,
      aws_vpn_gateway_attachment.this[*].vpn_gateway_id,
    ),
    0,
  )
}

resource "aws_vpn_gateway_route_propagation" "private" {
  count = local.create_vpc && var.enable_vpn_gateway && local.create_private_subnets ? local.nat_gateway_count : 0

  route_table_id = element(aws_route_table.private[*].id, count.index)
  vpn_gateway_id = element(
    concat(
      aws_vpn_gateway.this[*].id,
      aws_vpn_gateway_attachment.this[*].vpn_gateway_id,
    ),
    0,
  )
}

resource "aws_vpn_gateway_route_propagation" "intra" {
  count = local.create_vpc && var.enable_vpn_gateway && local.create_intra_subnets ? 1 : 0

  route_table_id = element(aws_route_table.intra[*].id, 0)
  vpn_gateway_id = element(
    concat(
      aws_vpn_gateway.this[*].id,
      aws_vpn_gateway_attachment.this[*].vpn_gateway_id,
    ),
    0,
  )
}

resource "aws_vpn_gateway_route_propagation" "outpost" {
  count = local.create_vpc && var.enable_vpn_gateway && local.create_outpost_subnets ? 1 : 0

  route_table_id = element(aws_route_table.outpost[*].id, 0)
  vpn_gateway_id = element(
    concat(
      aws_vpn_gateway.this[*].id,
      aws_vpn_gateway_attachment.this[*].vpn_gateway_id,
    ),
    0,
  )
}
