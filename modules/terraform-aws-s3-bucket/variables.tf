variable "name" {
  description = "AWS 파티션에서 고유한 범용 S3 버킷 이름"
  type        = string
  nullable    = false
}

variable "kms_key_arn" {
  description = "SSE-KMS에 사용할 KMS 키 ARN. 생략하면 SSE-S3를 사용합니다."
  type        = string
  default     = null
}

variable "tags" {
  description = "AWS 프로바이더 공통 태그에 더할 태그"
  type        = map(string)
  default     = {}
  nullable    = false
}
