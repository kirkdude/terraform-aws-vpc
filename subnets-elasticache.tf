################################################################################
# Elasticache Subnets
################################################################################

resource "aws_subnet" "elasticache" {
  count = local.create_elasticache_subnets ? local.len_elasticache_subnets : 0

  assign_ipv6_address_on_creation                = var.enable_ipv6 && var.elasticache_subnet_ipv6_native ? true : var.elasticache_subnet_assign_ipv6_address_on_creation
  availability_zone                              = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id                           = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  cidr_block                                     = var.elasticache_subnet_ipv6_native ? null : element(concat(var.elasticache_subnets, [""]), count.index)
  enable_dns64                                   = var.enable_ipv6 && var.elasticache_subnet_enable_dns64
  enable_resource_name_dns_aaaa_record_on_launch = var.enable_ipv6 && var.elasticache_subnet_enable_resource_name_dns_aaaa_record_on_launch
  enable_resource_name_dns_a_record_on_launch    = !var.elasticache_subnet_ipv6_native && var.elasticache_subnet_enable_resource_name_dns_a_record_on_launch
  ipv6_cidr_block                                = var.enable_ipv6 && length(var.elasticache_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, var.elasticache_subnet_ipv6_prefixes[count.index]) : null
  ipv6_native                                    = var.enable_ipv6 && var.elasticache_subnet_ipv6_native
  private_dns_hostname_type_on_launch            = var.elasticache_subnet_private_dns_hostname_type_on_launch
  vpc_id                                         = local.vpc_id

  tags = merge(
    {
      Name = try(
        var.elasticache_subnet_names[count.index],
        format("${var.name}-${var.elasticache_subnet_suffix}-%s", element(var.azs, count.index), )
      )
    },
    var.tags,
    var.elasticache_subnet_tags,
  )
}

resource "aws_elasticache_subnet_group" "elasticache" {
  count = local.create_elasticache_subnets && var.create_elasticache_subnet_group ? 1 : 0

  name        = coalesce(var.elasticache_subnet_group_name, var.name)
  description = "Elasticache subnet group for ${var.name}"
  subnet_ids  = aws_subnet.elasticache[*].id

  tags = merge(
    {
      "Name" = coalesce(var.elasticache_subnet_group_name, var.name)
    },
    var.tags,
    var.elasticache_subnet_group_tags,
  )
}

resource "aws_route_table" "elasticache" {
  count = local.create_elasticache_route_table ? var.single_nat_gateway ? 1 : local.len_elasticache_subnets : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "${var.name}-${var.elasticache_subnet_suffix}" : format(
        "${var.name}-${var.elasticache_subnet_suffix}-%s",
        element(var.azs, count.index),
      )
    },
    var.tags,
    var.elasticache_route_table_tags,
  )
}

resource "aws_route_table_association" "elasticache" {
  count = local.create_elasticache_subnets ? local.len_elasticache_subnets : 0

  subnet_id = element(aws_subnet.elasticache[*].id, count.index)
  route_table_id = element(
    coalescelist(aws_route_table.elasticache[*].id, aws_route_table.private[*].id),
    var.create_elasticache_subnet_route_table ? var.single_nat_gateway ? 0 : count.index : count.index,
  )
}

resource "aws_route" "elasticache_nat_gateway" {
  count = local.create_elasticache_route_table && var.enable_nat_gateway ? var.single_nat_gateway ? 1 : local.len_elasticache_subnets : 0

  route_table_id         = element(aws_route_table.elasticache[*].id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "elasticache_ipv6_egress" {
  count = local.create_elasticache_route_table && var.create_egress_only_igw && var.enable_ipv6 ? 1 : 0

  route_table_id              = element(aws_route_table.elasticache[*].id, count.index)
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.this[0].id
}

################################################################################
# Elasticache Network ACLs
################################################################################

resource "aws_network_acl" "elasticache" {
  count = local.create_elasticache_subnets && var.elasticache_dedicated_network_acl ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = aws_subnet.elasticache[*].id

  tags = merge(
    { "Name" = "${var.name}-${var.elasticache_subnet_suffix}" },
    var.tags,
    var.elasticache_acl_tags,
  )
}

resource "aws_network_acl_rule" "elasticache_inbound" {
  count = local.create_elasticache_subnets && var.elasticache_dedicated_network_acl ? length(var.elasticache_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.elasticache[0].id

  egress          = false
  rule_number     = var.elasticache_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.elasticache_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.elasticache_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.elasticache_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.elasticache_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.elasticache_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.elasticache_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.elasticache_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.elasticache_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "elasticache_outbound" {
  count = local.create_elasticache_subnets && var.elasticache_dedicated_network_acl ? length(var.elasticache_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.elasticache[0].id

  egress          = true
  rule_number     = var.elasticache_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.elasticache_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.elasticache_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.elasticache_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.elasticache_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.elasticache_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.elasticache_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.elasticache_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.elasticache_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}
