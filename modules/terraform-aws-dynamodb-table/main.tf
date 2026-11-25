terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.100"
    }
  }
}

locals {
  keys = var.sort_key == null ? [var.partition_key] : [var.partition_key, var.sort_key]
}

resource "aws_dynamodb_table" "this" {
  name                        = var.name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = var.partition_key.name
  range_key                   = var.sort_key == null ? null : var.sort_key.name
  deletion_protection_enabled = var.deletion_protection
  tags                        = var.tags

  dynamic "attribute" {
    for_each = { for key in local.keys : key.name => key.type }
    content {
      name = attribute.key
      type = attribute.value
    }
  }
  point_in_time_recovery {
    enabled = true
  }
  dynamic "ttl" {
    for_each = var.ttl_attribute == null ? [] : [var.ttl_attribute]
    content {
      enabled        = true
      attribute_name = ttl.value
    }
  }
  dynamic "server_side_encryption" {
    for_each = var.kms_key_arn == null ? [] : [var.kms_key_arn]
    content {
      enabled     = true
      kms_key_arn = server_side_encryption.value
    }
  }
}
