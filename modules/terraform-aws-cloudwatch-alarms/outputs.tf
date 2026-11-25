output "alarm_arns" {
  value = { for name, alarm in aws_cloudwatch_metric_alarm.this : name => alarm.arn }
}
