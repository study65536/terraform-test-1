variable "name" {
  type = string
}
variable "partition_key" {
  type = object({ name = string, type = string })
  validation {
    condition     = contains(["S", "N", "B"], var.partition_key.type)
    error_message = "파티션 키 타입은 S, N, B 중 하나여야 합니다."
  }
}
variable "sort_key" {
  type    = object({ name = string, type = string })
  default = null
  validation {
    condition     = var.sort_key == null ? true : contains(["S", "N", "B"], var.sort_key.type) && var.sort_key.name != var.partition_key.name
    error_message = "정렬 키는 고유한 이름과 S, N, B 중 하나의 타입을 사용하세요."
  }
}
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "ttl_attribute" {
  type        = string
  default     = null
  description = "만료 시각(Unix epoch 초)이 저장되는 속성"
}
variable "kms_key_arn" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}
