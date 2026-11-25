variable "instance_arn" {
  description = "IAM Identity Center 조직 인스턴스 ARN"
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:sso:::instance/(sso)?ins-[.a-zA-Z0-9-]{16}$", var.instance_arn))
    error_message = "조직에서 사용 중인 Identity Center 인스턴스 ARN을 입력하세요."
  }
}

variable "inventory_readers" {
  description = "서비스·환경별 EC2 메타데이터 조회 권한을 부여할 Identity Store 그룹 ID"
  type = set(object({
    service     = string
    environment = string
    group_id    = string
  }))
  default = []
}

locals {
  catalog = jsondecode(file("${path.module}/../../catalog/accounts.json"))
  # IAM Identity Center assignments are scoped to an AWS account, group and permission set.
  reader_accounts = [
    for reader in var.inventory_readers : {
      account_id = local.catalog.targets[local.catalog.services[reader.service].targets[reader.environment]].account_id
      group_id   = reader.group_id
    }
  ]
  grouped_readers = {
    for reader in local.reader_accounts :
    "${lookup(local.catalog.accounts[reader.account_id], "assignment_key", reader.account_id)}/${reader.group_id}" => reader...
  }
  assignments = { for key, readers in local.grouped_readers : key => readers[0] }
}

resource "aws_ssoadmin_permission_set" "inventory_reader" {
  name             = "EC2InventoryReader"
  description      = "Inspect EC2 instances, health and tags in the assigned account."
  instance_arn     = var.instance_arn
  session_duration = "PT1H"
}

resource "aws_ssoadmin_permission_set_inline_policy" "inventory_reader" {
  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.inventory_reader.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeTags",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_ssoadmin_account_assignment" "inventory_reader" {
  for_each = local.assignments

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.inventory_reader.arn
  principal_type     = "GROUP"
  principal_id       = each.value.group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = each.value.account_id

  depends_on = [aws_ssoadmin_permission_set_inline_policy.inventory_reader]
}
