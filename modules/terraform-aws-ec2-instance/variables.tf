variable "name" {
  type        = string
  description = "인스턴스의 Name 태그"
}

variable "ami_id" {
  type        = string
  description = "이 환경에서 배포할 검증된 리전별 AMI ID"
}

variable "instance_type" {
  type        = string
  description = "AMI 아키텍처와 호환되는 인스턴스 유형"
}

variable "subnet_id" {
  type        = string
  description = "인스턴스를 배치할 서브넷 ID"
}

variable "security_group_ids" {
  type        = list(string)
  description = "서비스에서 관리하는 보안 그룹 ID 목록"
  nullable    = false
  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "서비스 보안 그룹을 하나 이상 지정하세요."
  }
}

variable "key_name" {
  type        = string
  description = "SSH 접속에 사용할 기존 EC2 키 페어 이름"
  default     = null
}

variable "iam_instance_profile" {
  type        = string
  description = "SSM 또는 서비스 API 호출에 사용할 인스턴스 프로파일 이름"
  default     = null
}

variable "root_volume_size_gib" {
  type        = number
  description = "AMI 루트 볼륨 크기 이상의 용량(GiB)"
  default     = 20
}

variable "kms_key_arn" {
  type        = string
  description = "루트 EBS 암호화에 사용할 KMS 키 ARN"
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
