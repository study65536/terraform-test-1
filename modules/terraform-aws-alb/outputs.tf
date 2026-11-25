output "arn" {
  value = aws_lb.this.arn
}

output "dns_name" {
  value = aws_lb.this.dns_name
}

output "zone_id" {
  description = "ALB를 가리키는 Route 53 alias 레코드에 사용할 정식 호스팅 영역 ID"
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}
