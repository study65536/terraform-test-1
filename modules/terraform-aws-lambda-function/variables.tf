variable "name" {
  type = string
}
variable "package" {
  description = "함수 리전의 버전 관리 S3 버킷에 빌드 파이프라인이 올린 ZIP"
  type = object({
    bucket  = string
    key     = string
    version = string
  })
  validation {
    condition     = try(length(trimspace(var.package.version)) > 0 && var.package.version != "null", false)
    error_message = "S3 버전 관리가 활성화된 객체의 버전 ID를 지정하세요."
  }
}
variable "handler" {
  type = string
}
variable "runtime" {
  type = string
}
variable "execution_role_arn" {
  type = string
}
variable "memory_mb" {
  type    = number
  default = 256
}
variable "timeout_seconds" {
  type    = number
  default = 30
}
variable "environment_variables" {
  type    = map(string)
  default = {}
}
variable "log_retention_days" {
  type    = number
  default = 30
}
variable "tags" {
  type    = map(string)
  default = {}
}
