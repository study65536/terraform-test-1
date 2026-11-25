terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

locals {
  name = "${var.service_code}-${var.environment}"
  subnets_by_az = {
    for index, az in var.workload.availability_zones : az => {
      public_cidr  = cidrsubnet(var.workload.vpc_cidr, 4, index)
      private_cidr = cidrsubnet(var.workload.vpc_cidr, 4, 8 + index)
    }
  }
  has_instances = length(var.workload.instances) > 0
}

module "vpc" {
  count  = local.owns_network ? 1 : 0
  source = "../../modules/terraform-aws-vpc"

  name               = local.name
  vpc_cidr           = var.workload.vpc_cidr
  subnets_by_az      = local.subnets_by_az
  nat_gateway_per_az = var.workload.nat_gateway_per_az
  flow_log           = var.workload.flow_log
}

resource "aws_security_group" "compute" {
  count = local.has_instances ? 1 : 0

  name_prefix = "${local.name}-ec2-"
  description = "Private service instances"
  vpc_id      = local.vpc_id
  tags        = { Name = "${local.name}-ec2" }
}

resource "aws_vpc_security_group_ingress_rule" "controller_ssh" {
  count = local.has_instances && var.workload.ssh_source_sg_id != null ? 1 : 0

  security_group_id            = aws_security_group.compute[0].id
  referenced_security_group_id = var.workload.ssh_source_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "compute_https" {
  for_each = local.has_instances ? var.workload.https_egress_cidrs : toset([])

  security_group_id = aws_security_group.compute[0].id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

module "ec2_instance" {
  for_each = var.workload.instances
  source   = "../../modules/terraform-aws-ec2-instance"

  name                 = "${local.name}-${each.key}"
  ami_id               = each.value.ami_id
  instance_type        = each.value.instance_type
  subnet_id            = local.private_subnet_ids_by_az[each.value.availability_zone]
  security_group_ids   = [aws_security_group.compute[0].id]
  key_name             = each.value.key_name
  iam_instance_profile = each.value.iam_instance_profile
  tags                 = { Role = each.value.role }
}

module "ebs_volume" {
  for_each = { for name, instance in var.workload.instances : name => instance if instance.data_disk_gib != null }
  source   = "../../modules/terraform-aws-ebs-volume"

  name              = "${local.name}-${each.key}-data"
  size_gib          = each.value.data_disk_gib
  availability_zone = each.value.availability_zone
  attachment        = { instance_id = module.ec2_instance[each.key].instance_id }
  final_snapshot    = var.environment == "prod"
}

module "s3_bucket" {
  count  = var.workload.enable_bucket ? 1 : 0
  source = "../../modules/terraform-aws-s3-bucket"

  name = "${local.name}-${var.account_id}-${var.region}-data"
}

module "ecr" {
  count  = var.workload.enable_registry ? 1 : 0
  source = "../../modules/terraform-aws-ecr"

  name                          = "${var.service_code}/${var.environment}"
  untagged_image_retention_days = 30
}

module "eks" {
  count  = var.workload.eks != null ? 1 : 0
  source = "../../modules/terraform-aws-eks"

  name                = local.name
  kubernetes_version  = var.workload.eks.kubernetes_version
  admin_principal_arn = var.workload.eks.admin_principal_arn
  subnet_ids_by_az    = local.private_subnet_ids_by_az

  # Worker bootstrap uses the network's private routes and NAT gateways.
  depends_on = [module.vpc]
}

resource "aws_vpc_security_group_ingress_rule" "eks_admin_api" {
  count = try(var.workload.eks.api_client_sg_id, null) != null ? 1 : 0

  security_group_id            = module.eks[0].cluster_security_group_id
  referenced_security_group_id = var.workload.eks.api_client_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

module "efs" {
  count  = var.workload.enable_efs ? 1 : 0
  source = "../../modules/terraform-aws-efs"

  name             = local.name
  vpc_id           = local.vpc_id
  subnet_ids_by_az = local.private_subnet_ids_by_az
  client_security_group_ids = merge(
    local.has_instances ? { ec2 = aws_security_group.compute[0].id } : {},
    var.workload.eks != null || var.workload.shared_eks_cluster_name != null ? { eks = local.eks_security_group_id } : {}
  )
}

resource "aws_vpc_security_group_egress_rule" "compute_nfs" {
  count = local.has_instances && var.workload.enable_efs ? 1 : 0

  security_group_id            = aws_security_group.compute[0].id
  referenced_security_group_id = module.efs[0].security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
}
