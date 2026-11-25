terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.100"
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.name
  assume_role_policy   = var.trust_policy_json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies
  name     = each.key
  role     = aws_iam_role.this.id
  policy   = each.value
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = var.managed_policy_arns
  role       = aws_iam_role.this.name
  policy_arn = each.value
}
