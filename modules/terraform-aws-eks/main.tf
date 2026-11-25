terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.100"
    }
  }
}

data "aws_partition" "current" {}

data "aws_default_tags" "current" {}

data "aws_subnet" "cluster" {
  for_each = var.subnet_ids_by_az
  id       = each.value
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "${var.name}-control-plane" })
}

resource "aws_eks_cluster" "this" {
  name                      = var.name
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.kubernetes_version
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = values(var.subnet_ids_by_az)
    endpoint_private_access = true
    endpoint_public_access  = length(var.public_access_cidrs) > 0
    public_access_cidrs     = length(var.public_access_cidrs) > 0 ? var.public_access_cidrs : null
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition = alltrue([
        for az, subnet in data.aws_subnet.cluster : subnet.availability_zone == az
      ])
      error_message = "subnet_ids_by_az의 각 키는 서브넷의 실제 가용 영역 이름과 일치해야 합니다."
    }

    precondition {
      condition     = length(toset([for subnet in data.aws_subnet.cluster : subnet.vpc_id])) == 1
      error_message = "EKS 서브넷들은 같은 VPC에 속해야 합니다."
    }
  }

  depends_on = [aws_iam_role_policy_attachment.cluster, aws_cloudwatch_log_group.cluster]
}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"

  tags = merge(var.tags, { Name = "${var.name}-admin" })
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_launch_template" "nodes" {
  name_prefix = "${var.name}-nodes-"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted             = true
      delete_on_termination = true
      volume_size           = var.node_group.disk_size_gib
      volume_type           = "gp3"
    }
  }

  metadata_options {
    http_tokens = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(data.aws_default_tags.current.tags, var.tags, { Name = "${var.name}-node" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(data.aws_default_tags.current.tags, var.tags, { Name = "${var.name}-node-root" })
  }

  tags = merge(var.tags, { Name = "${var.name}-nodes" })
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "general"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = values(var.subnet_ids_by_az)
  version         = aws_eks_cluster.this.version
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = var.node_group.instance_types
  capacity_type   = var.node_group.capacity_type

  launch_template {
    id      = aws_launch_template.nodes.id
    version = tostring(aws_launch_template.nodes.latest_version)
  }

  scaling_config {
    min_size     = var.node_group.min_size
    desired_size = var.node_group.desired_size
    max_size     = var.node_group.max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, { Name = "${var.name}-general" })

  depends_on = [aws_iam_role_policy_attachment.nodes]
}
