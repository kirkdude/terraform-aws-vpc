locals {
  len_public_subnets      = max(length(var.public_subnets), length(var.public_subnet_ipv6_prefixes))
  len_private_subnets     = max(length(var.private_subnets), length(var.private_subnet_ipv6_prefixes))
  len_database_subnets    = max(length(var.database_subnets), length(var.database_subnet_ipv6_prefixes))
  len_elasticache_subnets = max(length(var.elasticache_subnets), length(var.elasticache_subnet_ipv6_prefixes))
  len_redshift_subnets    = max(length(var.redshift_subnets), length(var.redshift_subnet_ipv6_prefixes))
  len_intra_subnets       = max(length(var.intra_subnets), length(var.intra_subnet_ipv6_prefixes))
  len_outpost_subnets     = max(length(var.outpost_subnets), length(var.outpost_subnet_ipv6_prefixes))

  max_subnet_length = max(
    local.len_private_subnets,
    local.len_public_subnets,
    local.len_elasticache_subnets,
    local.len_database_subnets,
    local.len_redshift_subnets,
  )

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = try(aws_vpc_ipv4_cidr_block_association.this[0].vpc_id, aws_vpc.this[0].id, "")

  create_vpc = var.create_vpc && var.putin_khuylo

  # Public subnet conditionals
  create_public_subnets   = local.create_vpc && local.len_public_subnets > 0
  num_public_route_tables = var.create_multiple_public_route_tables ? local.len_public_subnets : 1

  # Private subnet conditionals
  create_private_subnets     = local.create_vpc && local.len_private_subnets > 0
  create_private_network_acl = local.create_private_subnets && var.private_dedicated_network_acl

  # Database subnet conditionals
  create_database_subnets     = local.create_vpc && local.len_database_subnets > 0
  create_database_route_table = local.create_database_subnets && var.create_database_subnet_route_table
  create_database_network_acl = local.create_database_subnets && var.database_dedicated_network_acl

  # Redshift subnet conditionals
  create_redshift_subnets     = local.create_vpc && local.len_redshift_subnets > 0
  create_redshift_route_table = local.create_redshift_subnets && var.create_redshift_subnet_route_table

  # Elasticache subnet conditionals
  create_elasticache_subnets     = local.create_vpc && local.len_elasticache_subnets > 0
  create_elasticache_route_table = local.create_elasticache_subnets && var.create_elasticache_subnet_route_table

  # Intra subnet conditionals
  create_intra_subnets = local.create_vpc && local.len_intra_subnets > 0

  # Outpost subnet conditionals
  create_outpost_subnets = local.create_vpc && local.len_outpost_subnets > 0

  # NAT gateway conditionals
  nat_gateway_count = var.enable_nat_gateway ? var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length : 0
}

# Outputs-specific locals
locals {
  redshift_route_table_ids = aws_route_table.redshift[*].id
  public_route_table_ids   = aws_route_table.public[*].id
  private_route_table_ids  = aws_route_table.private[*].id
}
