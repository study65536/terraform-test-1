variable "hosted_zone_id" {
  type        = string
  description = "기존 Route 53 퍼블릭 또는 프라이빗 호스팅 영역 ID"
}

variable "records" {
  description = "안정적인 논리 이름별 단순 라우팅 레코드"
  type = map(object({
    name   = string
    type   = string
    ttl    = optional(number)
    values = optional(set(string), [])
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, false)
    }))
  }))
  validation {
    condition = alltrue([
      for record in values(var.records) : record.alias == null
      ? (length(record.values) > 0 && try(record.ttl >= 0 && floor(record.ttl) == record.ttl, false))
      : (length(record.values) == 0 && record.ttl == null)
    ])
    error_message = "일반 레코드에는 values와 0 이상의 정수 ttl을, 별칭 레코드에는 alias를 지정하세요."
  }
}
