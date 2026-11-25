resource "aws_vpc_endpoint" "gateway" {
  for_each = var.gateway_endpoints

  vpc_id            = var.vpc_id
  vpc_endpoint_type = "Gateway"
  service_name      = each.value.service_name
  route_table_ids   = each.value.route_table_ids
  policy            = each.value.policy
  tags              = merge(var.tags, { Name = each.key })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = var.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = each.value.service_name
  subnet_ids          = each.value.subnet_ids
  security_group_ids  = each.value.security_group_ids
  private_dns_enabled = each.value.private_dns_enabled
  policy              = each.value.policy
  tags                = merge(var.tags, { Name = each.key })
}
