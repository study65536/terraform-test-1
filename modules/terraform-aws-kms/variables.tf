variable "alias_name" {
  type = string
  validation {
    condition     = can(regex("^alias/[A-Za-z0-9/_-]+$", var.alias_name)) && !startswith(var.alias_name, "alias/aws/") && length(var.alias_name) <= 256
    error_message = "사용자 관리 KMS 별칭은 alias/로 시작하고 alias/aws/ 접두사는 피해야 합니다."
  }
}
variable "description" {
  type = string
}
variable "policy_json" {
  type        = string
  default     = null
  description = "키 정책 JSON. 생략하면 AWS가 키 소유 계정의 IAM에 권한을 위임하는 기본 정책을 적용합니다."
}
variable "deletion_window_in_days" {
  type    = number
  default = 30
  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30 && floor(var.deletion_window_in_days) == var.deletion_window_in_days
    error_message = "삭제 대기 기간은 7~30일 사이 정수입니다."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
