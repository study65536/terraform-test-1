variable "identifier" {
  type        = string
  description = "RDS 인스턴스 및 DB 서브넷 그룹의 고유 이름"
}

variable "private_subnet_ids" {
  type        = set(string)
  description = "같은 VPC의 서로 다른 두 AZ 이상에 있는 프라이빗 서브넷"
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "DB 서브넷 그룹에 서로 다른 두 AZ 이상의 서브넷을 지정하세요."
  }
}

variable "security_group_ids" {
  type        = set(string)
  description = "애플리케이션에서 PostgreSQL 접속을 허용하는 데이터베이스 보안 그룹"
  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "데이터베이스 보안 그룹 ID를 하나 이상 지정하세요."
  }
}

variable "engine_version" {
  type        = string
  description = "해당 리전에서 제공하는 RDS PostgreSQL 버전"
}

variable "instance_class" {
  type        = string
  description = "대상 버전에 사용 가능한 DB 인스턴스 클래스"
}

variable "database_name" {
  type        = string
  description = "생성할 첫 PostgreSQL 데이터베이스 이름"
}

variable "master_username" {
  type        = string
  default     = "dbadmin"
  description = "RDS에서 비밀번호를 관리할 관리자 계정"
}

variable "storage_gib" {
  type        = number
  default     = 20
  description = "gp3 스토리지 용량(GiB)"
}

variable "storage_kms_key_arn" {
  type        = string
  default     = null
  description = "스토리지 암호화에 사용할 키 ARN. 생략하면 AWS 관리 키를 사용합니다."
}

variable "multi_az" {
  type        = bool
  default     = true
  description = "다른 가용 영역에 동기식 대기 인스턴스 생성"
}

variable "backup_retention_days" {
  type    = number
  default = 7
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35 && floor(var.backup_retention_days) == var.backup_retention_days
    error_message = "백업 보존 기간을 1~35일 사이 정수로 지정하세요."
  }
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "final_snapshot_identifier" {
  type        = string
  description = "삭제 시 최종 스냅샷으로 사용할 리전 내 고유 식별자"
}

variable "tags" {
  type    = map(string)
  default = {}
}
