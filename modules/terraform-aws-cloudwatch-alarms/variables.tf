variable "alarms" {
  description = "경보 이름별 단일 지표와 임계값 설정"
  type = map(object({
    description         = optional(string)
    namespace           = string
    metric_name         = string
    dimensions          = optional(map(string), {})
    statistic           = optional(string, "Average")
    period_seconds      = optional(number, 300)
    evaluation_periods  = optional(number, 3)
    datapoints_to_alarm = optional(number)
    comparison_operator = optional(string, "GreaterThanThreshold")
    threshold           = number
    treat_missing_data  = optional(string, "missing")
    alarm_action_arns   = optional(set(string), [])
    ok_action_arns      = optional(set(string), [])
  }))
  validation {
    condition = alltrue([
      for alarm in values(var.alarms) :
      alarm.evaluation_periods >= 1 && floor(alarm.evaluation_periods) == alarm.evaluation_periods &&
      (alarm.datapoints_to_alarm == null ? true : (
        alarm.datapoints_to_alarm >= 1 && alarm.datapoints_to_alarm <= alarm.evaluation_periods &&
        floor(alarm.datapoints_to_alarm) == alarm.datapoints_to_alarm
      ))
    ])
    error_message = "평가 구간 수는 양의 정수이며 임계값 초과 구간 수는 평가 구간 수 이하여야 합니다."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
