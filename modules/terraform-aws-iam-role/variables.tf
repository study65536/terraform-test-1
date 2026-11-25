variable "name" {
  type        = string
  description = "계정에서 고유한 역할 이름"
}
variable "trust_policy_json" {
  type        = string
  description = "역할을 맡을 주체, 액션과 조건을 명시한 IAM 신뢰 정책 JSON"
}
variable "permissions_boundary_arn" {
  type    = string
  default = null
}
variable "inline_policies" {
  type        = map(string)
  default     = {}
  description = "정책 이름별 권한 정책 JSON"
}
variable "managed_policy_arns" {
  type        = map(string)
  default     = {}
  description = "안정적인 논리 키별 연결할 관리형 정책 ARN"
}
variable "tags" {
  type    = map(string)
  default = {}
}
