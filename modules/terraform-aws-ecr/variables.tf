variable "name" {
  description = "프라이빗 ECR 리포지토리 이름"
  type        = string
  nullable    = false
}

variable "kms_key_arn" {
  description = "ECR에서 사용할 KMS 키 ARN. 생략하면 AES256 암호화를 사용합니다."
  type        = string
  default     = null
}

variable "untagged_image_retention_days" {
  description = "태그가 없는 이미지의 푸시 시점부터 만료까지의 일수. 생략하면 자동 만료 정책을 만들지 않습니다."
  type        = number
  default     = null

  validation {
    condition = var.untagged_image_retention_days == null ? true : (
      var.untagged_image_retention_days >= 1 &&
      floor(var.untagged_image_retention_days) == var.untagged_image_retention_days
    )
    error_message = "untagged_image_retention_days는 1 이상의 정수여야 합니다."
  }
}

variable "tags" {
  description = "AWS 프로바이더 공통 태그에 더할 태그"
  type        = map(string)
  default     = {}
  nullable    = false
}
