variable "name" {
  description = "큐 이름. FIFO 또는 DLQ 접미사는 모듈에서 붙입니다."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.name)) && length(var.name) + (var.fifo ? 5 : 0) + (var.max_receive_count == null ? 0 : 4) <= 80
    error_message = "이름은 영숫자·대시·밑줄로 작성하며 최종 큐 이름은 접미사 포함 최대 80자입니다."
  }
}
variable "fifo" {
  type    = bool
  default = false
}
variable "content_based_deduplication" {
  type        = bool
  default     = false
  description = "FIFO 큐에서 메시지 본문을 기준으로 중복 제거"
}
variable "max_receive_count" {
  type        = number
  default     = null
  description = "지정하면 같은 형식의 DLQ를 만들고 수신 횟수를 초과한 메시지를 격리합니다."
  validation {
    condition     = var.max_receive_count == null ? true : (var.max_receive_count >= 1 && var.max_receive_count <= 1000 && floor(var.max_receive_count) == var.max_receive_count)
    error_message = "max_receive_count는 1~1000 사이 정수입니다."
  }
}
variable "visibility_timeout_seconds" {
  type    = number
  default = 30
}
variable "message_retention_seconds" {
  type    = number
  default = 345600
}
variable "tags" {
  type    = map(string)
  default = {}
}
