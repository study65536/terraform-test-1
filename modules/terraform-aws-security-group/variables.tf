variable "name" {
  description = "보안 그룹의 이름 접두사와 Name 태그"
  type        = string
}

variable "vpc_id" {
  description = "보안 그룹을 생성할 VPC"
  type        = string
}

variable "rules" {
  description = "업무 목적을 키로 지정한 상태 저장형 네트워크 규칙. 각 규칙에 피어 하나를 지정합니다."
  type = map(object({
    direction                    = string
    description                  = optional(string)
    ip_protocol                  = string
    from_port                    = optional(number)
    to_port                      = optional(number)
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    prefix_list_id               = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([for rule in values(var.rules) :
      contains(["ingress", "egress"], rule.direction) &&
      length([for peer in [rule.cidr_ipv4, rule.cidr_ipv6, rule.referenced_security_group_id, rule.prefix_list_id] : peer if peer != null]) == 1
    ])
    error_message = "각 규칙에는 ingress 또는 egress 방향과 CIDR·보안 그룹·프리픽스 목록 중 한 개의 피어가 필요합니다."
  }

  validation {
    condition = alltrue([for rule in values(var.rules) :
      rule.ip_protocol == "-1" ? rule.from_port == null && rule.to_port == null :
      contains(["tcp", "udp"], rule.ip_protocol) ? try(rule.from_port >= 0 && rule.from_port <= rule.to_port && rule.to_port <= 65535, false) :
      contains(["icmp", "icmpv6"], rule.ip_protocol) && try(rule.from_port >= -1 && rule.from_port <= 255 && rule.to_port >= -1 && rule.to_port <= 255, false)
    ])
    error_message = "tcp·udp에는 포트 범위, icmp·icmpv6에는 타입과 코드를 넣으세요. 전체 프로토콜(-1)은 포트를 생략하세요."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
