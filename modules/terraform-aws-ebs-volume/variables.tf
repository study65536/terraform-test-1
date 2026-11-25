variable "name" {
  description = "EBS 볼륨의 Name 태그"
  type        = string
  nullable    = false
}

variable "availability_zone" {
  description = "EBS 볼륨을 생성할 가용 영역. EC2에 연결할 경우 인스턴스와 같은 가용 영역을 사용합니다."
  type        = string
  nullable    = false
}

variable "size_gib" {
  description = "gp3 볼륨 크기(GiB)"
  type        = number
  nullable    = false

  validation {
    condition     = var.size_gib >= 1 && floor(var.size_gib) == var.size_gib
    error_message = "size_gib은 1 이상의 정수여야 합니다."
  }
}

variable "kms_key_arn" {
  description = "볼륨 암호화에 사용할 KMS 키 ARN. 생략하면 리전의 기본 EBS 암호화 키를 사용합니다."
  type        = string
  default     = null
}

variable "attachment" {
  description = "볼륨을 연결할 EC2 인스턴스와 EC2 장치 이름"
  type = object({
    instance_id = string
    device_name = optional(string, "/dev/sdf")
  })
  default = null
}

variable "final_snapshot" {
  description = "볼륨 삭제 직전에 최종 스냅샷을 생성할지 여부"
  type        = bool
  default     = false
  nullable    = false
}

variable "tags" {
  description = "AWS 프로바이더 공통 태그에 더할 태그"
  type        = map(string)
  default     = {}
  nullable    = false
}
