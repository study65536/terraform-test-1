terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_efs_file_system" "this" {
  encrypted       = true
  kms_key_id      = var.kms_key_arn
  throughput_mode = "elastic"

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = var.automatic_backups ? "ENABLED" : "DISABLED"
  }
}

resource "aws_security_group" "mount_targets" {
  name_prefix = "${var.name}-nfs-"
  description = "Allow NFS from the configured EFS clients"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-nfs" })
}

resource "aws_vpc_security_group_ingress_rule" "nfs" {
  for_each = var.client_security_group_ids

  security_group_id            = aws_security_group.mount_targets.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049

  tags = merge(var.tags, { Name = "${var.name}-nfs-${each.key}" })
}

data "aws_subnet" "mount_target" {
  for_each = var.subnet_ids_by_az
  id       = each.value
}

resource "aws_efs_mount_target" "this" {
  for_each = data.aws_subnet.mount_target

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value.id
  security_groups = [aws_security_group.mount_targets.id]

  lifecycle {
    precondition {
      condition     = each.value.availability_zone == each.key
      error_message = "subnet_ids_by_az의 키는 서브넷의 실제 가용 영역 이름과 일치해야 합니다."
    }

    precondition {
      condition     = each.value.vpc_id == var.vpc_id
      error_message = "EFS 마운트 대상 서브넷은 vpc_id로 지정한 VPC에 속해야 합니다."
    }
  }
}
