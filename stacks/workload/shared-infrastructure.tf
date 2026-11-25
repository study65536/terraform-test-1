locals {
  owns_network        = var.workload.shared_network_owner_code == null
  shared_network_name = local.owns_network ? null : "${var.workload.shared_network_owner_code}-${var.environment}"
  vpc_id              = local.owns_network ? module.vpc[0].vpc_id : data.aws_vpc.shared[0].id
  private_subnet_ids_by_az = local.owns_network ? module.vpc[0].private_subnet_ids_by_az : {
    for az, subnet in data.aws_subnet.shared : az => subnet.id
  }
  eks_cluster_name = var.workload.shared_eks_cluster_name == null ? one(module.eks[*].cluster_name) : data.aws_eks_cluster.shared[0].name
  eks_security_group_id = (
    var.workload.shared_eks_cluster_name == null
    ? one(module.eks[*].cluster_security_group_id)
    : data.aws_eks_cluster.shared[0].vpc_config[0].cluster_security_group_id
  )
}

data "aws_vpc" "shared" {
  count = local.owns_network ? 0 : 1
  tags = {
    ServiceCode = var.workload.shared_network_owner_code
    Environment = var.environment
    Name        = local.shared_network_name
  }

  lifecycle {
    postcondition {
      condition     = self.cidr_block == var.workload.vpc_cidr
      error_message = "네트워크 소유자가 배포한 VPC CIDR과 이 대상의 카탈로그 할당을 확인하세요."
    }
  }
}

data "aws_subnet" "shared" {
  for_each          = local.owns_network ? toset([]) : toset(var.workload.availability_zones)
  availability_zone = each.key
  vpc_id            = data.aws_vpc.shared[0].id
  tags = {
    Name = "${local.shared_network_name}-private-${each.key}"
  }
}

data "aws_eks_cluster" "shared" {
  count = var.workload.shared_eks_cluster_name == null ? 0 : 1
  name  = var.workload.shared_eks_cluster_name

  lifecycle {
    postcondition {
      condition     = self.vpc_config[0].vpc_id == local.vpc_id
      error_message = "공유 EKS 클러스터가 해당 배포 대상의 VPC에 있는지 확인하세요."
    }
  }
}
