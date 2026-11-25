variable "name" {
  description = "EFS 파일 시스템의 Name 태그"
  type        = string
  nullable    = false
}

variable "vpc_id" {
  description = "EFS 마운트 대상이 속할 VPC ID"
  type        = string
  nullable    = false
}

variable "subnet_ids_by_az" {
  description = "가용 영역 이름을 키로 사용하는 마운트 대상 서브넷 ID 맵. 가용 영역마다 서브넷 하나를 지정합니다."
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids_by_az) > 0
    error_message = "EFS 마운트 대상 서브넷을 하나 이상 지정해야 합니다."
  }
}

variable "client_security_group_ids" {
  description = "NFS 접속을 허용할 클라이언트 보안 그룹 ID 맵. 키는 클라이언트 이름을 사용합니다."
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.client_security_group_ids) > 0
    error_message = "NFS 클라이언트 보안 그룹을 하나 이상 지정해야 합니다."
  }
}

variable "kms_key_arn" {
  description = "파일 시스템 암호화에 사용할 KMS 키 ARN. 생략하면 EFS의 AWS 관리형 키를 사용합니다."
  type        = string
  default     = null
}

variable "automatic_backups" {
  description = "EFS의 AWS Backup 자동 백업 활성화 여부"
  type        = bool
  default     = true
  nullable    = false
}

variable "tags" {
  description = "AWS 프로바이더 공통 태그에 더할 태그"
  type        = map(string)
  default     = {}
  nullable    = false
}
