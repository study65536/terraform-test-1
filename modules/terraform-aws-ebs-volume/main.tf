terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_ebs_volume" "this" {
  availability_zone = var.availability_zone
  size              = var.size_gib
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn
  final_snapshot    = var.final_snapshot

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_volume_attachment" "this" {
  count = var.attachment == null ? 0 : 1

  volume_id   = aws_ebs_volume.this.id
  instance_id = var.attachment.instance_id
  device_name = var.attachment.device_name
}
