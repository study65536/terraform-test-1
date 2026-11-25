variable "vpc_id" {
  description = "엔드포인트를 설치할 VPC"
  type        = string
}

variable "gateway_endpoints" {
  description = "별칭별 S3·DynamoDB 게이트웨이 엔드포인트 및 연결할 라우팅 테이블"
  type = map(object({
    service_name    = string
    route_table_ids = set(string)
    policy          = optional(string)
  }))
  default = {}
  validation {
    condition     = alltrue([for endpoint in values(var.gateway_endpoints) : length(endpoint.route_table_ids) > 0])
    error_message = "게이트웨이 엔드포인트마다 연결할 라우팅 테이블이 필요합니다."
  }
}

variable "interface_endpoints" {
  description = "별칭별 PrivateLink 엔드포인트. 서로 다른 AZ의 서브넷과 클라이언트 접근을 허용하는 SG를 지정합니다."
  type = map(object({
    service_name        = string
    subnet_ids          = set(string)
    security_group_ids  = set(string)
    private_dns_enabled = optional(bool, true)
    policy              = optional(string)
  }))
  default = {}
  validation {
    condition = alltrue([for endpoint in values(var.interface_endpoints) :
      length(endpoint.subnet_ids) > 0 && length(endpoint.security_group_ids) > 0
    ])
    error_message = "인터페이스 엔드포인트마다 서브넷과 보안 그룹이 하나 이상 필요합니다."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
