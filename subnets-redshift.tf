################################################################################
# Redshift Subnets
################################################################################

resource "aws_subnet" "redshift" {
  count = local.create_redshift_subnets ? local.len_redshift_subnets : 0

  assign_ipv6_address_on_creation                = var.enable_ipv6 && var.redshift_subnet_ipv6_native ? true : var.redshift_subnet_assign_ipv6_address_on_creation
  availability_zone                              = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id                           = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  cidr_block                                     = var.redshift_subnet_ipv6_native ? null : element(concat(var.redshift_subnets, [""]), count.index)
  enable_dns64                                   = var.enable_ipv6 && var.redshift_subnet_enable_dns64
  enable_resource_name_dns_aaaa_record_on_launch = var.enable_ipv6 && var.redshift_subnet_enable_resource_name_dns_aaaa_record_on_launch
  enable_resource_name_dns_a_record_on_launch    = !var.redshift_subnet_ipv6_native && var.redshift_subnet_enable_resource_name_dns_a_record_on_launch
  ipv6_cidr_block                                = var.enable_ipv6 && length(var.redshift_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, var.redshift_subnet_ipv6_prefixes[count.index]) : null
  ipv6_native                                    = var.enable_ipv6 && var.redshift_subnet_ipv6_native
  private_dns_hostname_type_on_launch            = var.redshift_subnet_private_dns_hostname_type_on_launch
  vpc_id                                         = local.vpc_id

  tags = merge(
    {
      Name = try(
        var.redshift_subnet_names[count.index],
        format("${var.name}-${var.redshift_subnet_suffix}-%s", element(var.azs, count.index), )
      )
    },
    var.tags,
    var.redshift_subnet_tags,
  )
}

resource "aws_redshift_subnet_group" "redshift" {
  count = local.create_redshift_subnets && var.create_redshift_subnet_group ? 1 : 0

  name        = coalesce(var.redshift_subnet_group_name, var.name)
  description = "Redshift subnet group for ${var.name}"
  subnet_ids  = aws_subnet.redshift[*].id

  tags = merge(
    {
      "Name" = coalesce(var.redshift_subnet_group_name, var.name)
    },
    var.tags,
    var.redshift_subnet_group_tags,
  )
}

resource "aws_route_table" "redshift" {
  count = local.create_redshift_route_table ? var.single_nat_gateway ? 1 : local.len_redshift_subnets : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "${var.name}-${var.redshift_subnet_suffix}" : format(
        "${var.name}-${var.redshift_subnet_suffix}-%s",
        element(var.azs, count.index),
      )
    },
    var.tags,
    var.redshift_route_table_tags,
  )
}

resource "aws_route_table_association" "redshift" {
  count = local.create_redshift_subnets ? local.len_redshift_subnets : 0

  subnet_id = element(aws_subnet.redshift[*].id, count.index)
  route_table_id = element(
    coalescelist(aws_route_table.redshift[*].id, aws_route_table.private[*].id),
    var.create_redshift_subnet_route_table ? var.single_nat_gateway ? 0 : count.index : count.index,
  )
}

resource "aws_route" "redshift_nat_gateway" {
  count = local.create_redshift_route_table && var.enable_nat_gateway ? var.single_nat_gateway ? 1 : local.len_redshift_subnets : 0

  route_table_id         = element(aws_route_table.redshift[*].id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "redshift_ipv6_egress" {
  count = local.create_redshift_route_table && var.create_egress_only_igw && var.enable_ipv6 ? 1 : 0

  route_table_id              = element(aws_route_table.redshift[*].id, count.index)
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.this[0].id
}

################################################################################
# Redshift Network ACLs
################################################################################

resource "aws_network_acl" "redshift" {
  count = local.create_redshift_subnets && var.redshift_dedicated_network_acl ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = aws_subnet.redshift[*].id

  tags = merge(
    { "Name" = "${var.name}-${var.redshift_subnet_suffix}" },
    var.tags,
    var.redshift_acl_tags,
  )
}

resource "aws_network_acl_rule" "redshift_inbound" {
  count = local.create_redshift_subnets && var.redshift_dedicated_network_acl ? length(var.redshift_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.redshift[0].id

  egress          = false
  rule_number     = var.redshift_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.redshift_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.redshift_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.redshift_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.redshift_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.redshift_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.redshift_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.redshift_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.redshift_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "redshift_outbound" {
  count = local.create_redshift_subnets && var.redshift_dedicated_network_acl ? length(var.redshift_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.redshift[0].id

  egress          = true
  rule_number     = var.redshift_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.redshift_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.redshift_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.redshift_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.redshift_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.redshift_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.redshift_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.redshift_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.redshift_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}
