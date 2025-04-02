################################################################################
# Outpost Subnets
################################################################################

resource "aws_subnet" "outpost" {
  count = local.create_outpost_subnets ? local.len_outpost_subnets : 0

  assign_ipv6_address_on_creation                = var.enable_ipv6 && var.outpost_subnet_ipv6_native ? true : var.outpost_subnet_assign_ipv6_address_on_creation
  availability_zone                              = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id                           = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  cidr_block                                     = var.outpost_subnet_ipv6_native ? null : element(concat(var.outpost_subnets, [""]), count.index)
  outpost_arn                                    = var.outpost_arn
  customer_owned_ipv4_pool                       = var.customer_owned_ipv4_pool
  enable_dns64                                   = var.enable_ipv6 && var.outpost_subnet_enable_dns64
  enable_resource_name_dns_aaaa_record_on_launch = var.enable_ipv6 && var.outpost_subnet_enable_resource_name_dns_aaaa_record_on_launch
  enable_resource_name_dns_a_record_on_launch    = !var.outpost_subnet_ipv6_native && var.outpost_subnet_enable_resource_name_dns_a_record_on_launch
  ipv6_cidr_block                                = var.enable_ipv6 && length(var.outpost_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, var.outpost_subnet_ipv6_prefixes[count.index]) : null
  ipv6_native                                    = var.enable_ipv6 && var.outpost_subnet_ipv6_native
  map_customer_owned_ip_on_launch                = var.map_customer_owned_ip_on_launch
  private_dns_hostname_type_on_launch            = var.outpost_subnet_private_dns_hostname_type_on_launch
  vpc_id                                         = local.vpc_id

  tags = merge(
    {
      Name = try(
        var.outpost_subnet_names[count.index],
        format("${var.name}-${var.outpost_subnet_suffix}-%s", element(var.azs, count.index), )
      )
    },
    var.tags,
    var.outpost_subnet_tags,
  )
}

resource "aws_route_table" "outpost" {
  count = local.create_outpost_subnets ? 1 : 0

  vpc_id = local.vpc_id
  # Route tables don't support outpost_arn, only subnets do

  tags = merge(
    { "Name" = "${var.name}-${var.outpost_subnet_suffix}" },
    var.tags,
    var.outpost_route_table_tags,
  )
}

resource "aws_route_table_association" "outpost" {
  count = local.create_outpost_subnets ? local.len_outpost_subnets : 0

  subnet_id      = element(aws_subnet.outpost[*].id, count.index)
  route_table_id = aws_route_table.outpost[0].id
}

################################################################################
# Outpost Network ACLs
################################################################################

resource "aws_network_acl" "outpost" {
  count = local.create_outpost_subnets && var.outpost_dedicated_network_acl ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = aws_subnet.outpost[*].id

  tags = merge(
    { "Name" = "${var.name}-${var.outpost_subnet_suffix}" },
    var.tags,
    var.outpost_acl_tags,
  )
}

resource "aws_network_acl_rule" "outpost_inbound" {
  count = local.create_outpost_subnets && var.outpost_dedicated_network_acl ? length(var.outpost_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.outpost[0].id

  egress          = false
  rule_number     = var.outpost_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.outpost_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.outpost_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.outpost_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.outpost_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.outpost_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.outpost_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.outpost_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.outpost_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "outpost_outbound" {
  count = local.create_outpost_subnets && var.outpost_dedicated_network_acl ? length(var.outpost_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.outpost[0].id

  egress          = true
  rule_number     = var.outpost_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.outpost_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.outpost_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.outpost_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.outpost_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.outpost_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.outpost_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.outpost_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.outpost_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}
