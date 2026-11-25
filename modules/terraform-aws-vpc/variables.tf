variable "name" {
  type        = string
  description = "서비스와 환경을 식별하는 이름 접두사"
}

variable "vpc_cidr" {
  type        = string
  description = "조직의 IP 주소 계획에서 이 VPC에 할당한 IPv4 CIDR"
}

variable "subnets_by_az" {
  description = "AZ 이름별 퍼블릭·프라이빗 서브넷. 각 CIDR은 VPC 범위 안에서 고유해야 합니다."
  type = map(object({
    public_cidr  = string
    private_cidr = string
  }))
  nullable = false

  validation {
    condition     = length(var.subnets_by_az) >= 2
    error_message = "서로 다른 가용 영역을 두 개 이상 지정하세요."
  }
}

variable "nat_gateway_per_az" {
  description = "각 AZ에서 NAT 게이트웨이를 만들어 해당 AZ의 프라이빗 서브넷에 인터넷 경로를 제공합니다."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "flow_log" {
  description = "VPC Flow Logs를 기록할 기존 S3 버킷 ARN(선택적 접두사 포함). 중앙 버킷의 로그 전달 정책은 버킷 소유 계정에서 관리합니다."
  type = object({
    destination_arn     = string
    traffic_type        = optional(string, "ALL")
    aggregation_seconds = optional(number, 600)
  })
  default = null

  validation {
    condition = var.flow_log == null ? true : (
      can(regex("^arn:[^:]+:s3:::[^/]+(/.*)?$", var.flow_log.destination_arn)) &&
      contains(["ALL", "ACCEPT", "REJECT"], var.flow_log.traffic_type) &&
      contains([60, 600], var.flow_log.aggregation_seconds)
    )
    error_message = "S3 대상 ARN, ALL·ACCEPT·REJECT 중 한 가지 트래픽 유형, 60 또는 600초 집계 주기를 지정하세요."
  }
}
