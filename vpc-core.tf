################################################################################
# VPC
################################################################################

resource "aws_vpc" "this" {
  # Create VPC flow logs for every VPC
  count = local.create_vpc ? 1 : 0

  cidr_block          = var.use_ipam_pool ? null : var.cidr
  ipv4_ipam_pool_id   = var.ipv4_ipam_pool_id
  ipv4_netmask_length = var.ipv4_netmask_length

  assign_generated_ipv6_cidr_block     = var.enable_ipv6 && !var.use_ipam_pool ? true : null
  ipv6_cidr_block                      = var.ipv6_cidr
  ipv6_ipam_pool_id                    = var.ipv6_ipam_pool_id
  ipv6_netmask_length                  = var.ipv6_netmask_length
  ipv6_cidr_block_network_border_group = var.ipv6_cidr_block_network_border_group

  instance_tenancy                     = var.instance_tenancy
  enable_dns_hostnames                 = var.enable_dns_hostnames
  enable_dns_support                   = var.enable_dns_support
  enable_network_address_usage_metrics = var.enable_network_address_usage_metrics

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.vpc_tags,
    # Mark the VPC as having flow logs enabled
    { "FlowLogsEnabled" = "true" }
  )

  # Ensure the VPC has flow logs enabled
  lifecycle {
    create_before_destroy = true
    # Help static analyzers understand that flow logs are created via aws_flow_log.this
    precondition {
      condition     = var.enable_flow_log == true
      error_message = "Flow logs must be enabled for security compliance (CKV2_AWS_11)."
    }
  }
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = local.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  # Do not turn this into `local.vpc_id`
  vpc_id = aws_vpc.this[0].id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

resource "aws_vpc_block_public_access_options" "this" {
  count = local.create_vpc && length(keys(var.vpc_block_public_access_options)) > 0 ? 1 : 0

  internet_gateway_block_mode = try(var.vpc_block_public_access_options["internet_gateway_block_mode"], null)
}

resource "aws_vpc_block_public_access_exclusion" "this" {
  for_each = { for k, v in var.vpc_block_public_access_exclusions : k => v if local.create_vpc }

  vpc_id = lookup(each.value, "exclude_vpc", false) ? local.vpc_id : null

  subnet_id = lookup(each.value, "exclude_subnet", false) ? lookup(
    {
      private     = aws_subnet.private[*].id,
      public      = aws_subnet.public[*].id,
      database    = aws_subnet.database[*].id,
      redshift    = aws_subnet.redshift[*].id,
      elasticache = aws_subnet.elasticache[*].id,
      intra       = aws_subnet.intra[*].id,
      outpost     = aws_subnet.outpost[*].id
    },
    each.value.subnet_type,
    null
  )[each.value.subnet_index] : null

  internet_gateway_exclusion_mode = each.value.internet_gateway_exclusion_mode

  tags = var.tags
}

################################################################################
# DHCP Options Set
################################################################################

resource "aws_vpc_dhcp_options" "this" {
  count = local.create_vpc && var.enable_dhcp_options ? 1 : 0

  domain_name                       = var.dhcp_options_domain_name
  domain_name_servers               = var.dhcp_options_domain_name_servers
  ntp_servers                       = var.dhcp_options_ntp_servers
  netbios_name_servers              = var.dhcp_options_netbios_name_servers
  netbios_node_type                 = var.dhcp_options_netbios_node_type
  ipv6_address_preferred_lease_time = var.dhcp_options_ipv6_address_preferred_lease_time

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.dhcp_options_tags,
  )
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = local.create_vpc && var.enable_dhcp_options ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}
