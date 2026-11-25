output "fqdns" {
  description = "입력 맵의 키별 정규화된 DNS 이름"
  value       = { for key, record in aws_route53_record.this : key => record.fqdn }
}
