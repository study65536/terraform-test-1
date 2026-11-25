variable "name" {
  description = "ALB 이름. 영문·숫자·하이픈 1~32자"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,30}[a-zA-Z0-9])?$", var.name)) && !startswith(lower(var.name), "internal-")
    error_message = "ALB 이름은 1~32자여야 하며 internal- 접두사를 사용할 수 없습니다."
  }
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "서로 다른 AZ에 위치한 동일 VPC 서브넷 ID 목록"
  type        = set(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "서로 다른 AZ의 서브넷 ID가 두 개 이상 필요합니다."
  }
}

variable "security_group_ids" {
  description = "클라이언트 TLS 접근과 타깃 포트로의 egress를 허용하는 ALB 보안 그룹"
  type        = set(string)
  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "ALB에 적용할 보안 그룹이 하나 이상 필요합니다."
  }
}

variable "certificate_arn" {
  description = "ALB와 같은 리전의 발급·검증된 TLS 인증서 ARN"
  type        = string
}

variable "internal" {
  description = "내부 ALB 설정. 인터넷 공개 시 public 서브넷과 함께 false를 지정합니다."
  type        = bool
  default     = true
}

variable "targets" {
  description = "서버의 논리 이름에서 EC2 인스턴스 ID로 매핑. ASG를 쓸 때는 비우고 target_group_arn을 ASG에 전달합니다."
  type        = map(string)
  default     = {}
}

variable "target_protocol" {
  description = "ALB와 대상 서버 간 프로토콜"
  type        = string
  default     = "HTTP"
  validation {
    condition     = contains(["HTTP", "HTTPS"], var.target_protocol)
    error_message = "HTTP 또는 HTTPS를 지정하세요."
  }
}

variable "target_port" {
  description = "서버의 수신 포트"
  type        = number
  default     = 80
  validation {
    condition     = floor(var.target_port) == var.target_port && var.target_port >= 1 && var.target_port <= 65535
    error_message = "target_port는 1~65535 사이 정수여야 합니다."
  }
}

variable "health_check_path" {
  description = "타깃에서 HTTP 200을 반환하는 경로"
  type        = string
  default     = "/healthz"
  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "헬스체크 경로는 /로 시작해야 합니다."
  }
}

variable "enable_http_redirect" {
  description = "80번 리스너에서 HTTPS 443으로 리다이렉트"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "운영 환경에서 ALB 삭제 방지"
  type        = bool
  default     = true
}

variable "access_logs" {
  description = "ALB 로그 쓰기 권한이 준비된 같은 리전의 S3 버킷"
  type = object({
    bucket = string
    prefix = optional(string)
  })
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
