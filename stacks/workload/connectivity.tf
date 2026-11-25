module "gateway_endpoints" {
  source = "../../modules/terraform-aws-vpc-endpoints"
  vpc_id = local.vpc_id
  gateway_endpoints = {
    for service in var.workload.gateway_endpoints : service => {
      service_name    = "com.amazonaws.${var.region}.${service}"
      route_table_ids = values(module.vpc[0].private_route_table_ids_by_az)
    }
  }
}

module "alb_security_group" {
  count  = var.workload.alb == null ? 0 : 1
  source = "../../modules/terraform-aws-security-group"
  name   = "${local.name}-alb"
  vpc_id = local.vpc_id
  rules = merge(
    { for cidr in var.workload.alb.client_cidrs : "https-${cidr}" => {
      direction   = "ingress"
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = cidr
    } },
    { backend = {
      direction                    = "egress"
      ip_protocol                  = "tcp"
      from_port                    = var.workload.alb.target_port
      to_port                      = var.workload.alb.target_port
      referenced_security_group_id = aws_security_group.compute[0].id
    } }
  )
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  count                        = var.workload.alb == null ? 0 : 1
  security_group_id            = aws_security_group.compute[0].id
  referenced_security_group_id = module.alb_security_group[0].security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.workload.alb.target_port
  to_port                      = var.workload.alb.target_port
}

module "internal_alb" {
  count                      = var.workload.alb == null ? 0 : 1
  source                     = "../../modules/terraform-aws-alb"
  name                       = local.name
  vpc_id                     = local.vpc_id
  subnet_ids                 = values(local.private_subnet_ids_by_az)
  security_group_ids         = [module.alb_security_group[0].security_group_id]
  certificate_arn            = var.workload.alb.certificate_arn
  targets                    = { for key in var.workload.alb.target_instances : key => module.ec2_instance[key].instance_id }
  target_port                = var.workload.alb.target_port
  health_check_path          = var.workload.alb.health_path
  enable_deletion_protection = var.environment == "prod"
}
