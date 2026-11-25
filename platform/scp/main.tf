variable "target_ou_ids" {
  description = "EBS 기본 암호화 해제를 제한할 OU ID 집합"
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.target_ou_ids : can(regex("^ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$", id))])
    error_message = "각 대상은 Organizations OU ID 형식이어야 합니다."
  }
}

resource "aws_organizations_policy" "ebs_defaults" {
  name        = "DenyDisablingEbsEncryptionByDefault"
  description = "Protect the EBS default encryption setting in member accounts."
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyDisablingEbsEncryptionByDefault"
      Effect   = "Deny"
      Action   = "ec2:DisableEbsEncryptionByDefault"
      Resource = "*"
    }]
  })
}

resource "aws_organizations_policy_attachment" "ebs_defaults" {
  for_each = var.target_ou_ids

  policy_id = aws_organizations_policy.ebs_defaults.id
  target_id = each.value
}
