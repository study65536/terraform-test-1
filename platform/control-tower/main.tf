variable "controls" {
  description = "배포할 Control Catalog의 전역 제어 ARN 및 대상 OU ARN"
  type = map(object({
    control_arn = string
    ou_arns     = set(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for entry in values(var.controls) :
      can(regex("^arn:[^:]+:controlcatalog:::control/[a-z0-9]+$", entry.control_arn)) &&
      alltrue([for ou in entry.ou_arns : can(regex("^arn:[^:]+:organizations::[0-9]{12}:ou/o-[a-z0-9]+/ou-[a-z0-9]+-[a-z0-9]+$", ou))])
    ])
    error_message = "제어에는 전역 Control Catalog ARN, 대상에는 Organizations OU ARN을 사용하세요."
  }
}

locals {
  controls_by_target = merge({}, [
    for entry in values(var.controls) : {
      for ou in entry.ou_arns : "${basename(entry.control_arn)}/${basename(ou)}" => {
        control_arn = entry.control_arn
        ou_arn      = ou
      }
    }
  ]...)
}

resource "aws_controltower_control" "optional" {
  for_each = local.controls_by_target

  control_identifier = each.value.control_arn
  target_identifier  = each.value.ou_arn
}
