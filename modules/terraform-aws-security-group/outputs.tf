output "security_group_id" {
  description = "EC2, ALB, VPC 인터페이스 엔드포인트 등에 연결할 보안 그룹 ID"
  value       = aws_security_group.this.id
}
