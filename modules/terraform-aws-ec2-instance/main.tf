terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile
  key_name                    = var.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    volume_size           = var.root_volume_size_gib
    volume_type           = "gp3"
    delete_on_termination = true
    tags                  = merge(var.tags, { Name = "${var.name}-root" })
  }

  tags = merge(var.tags, { Name = var.name })
}
