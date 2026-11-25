output "identifier" {
  value = aws_db_instance.this.identifier
}
output "address" {
  value = aws_db_instance.this.address
}
output "port" {
  value = aws_db_instance.this.port
}
output "master_secret_arn" {
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
  description = "Secrets Manager가 보관하는 관리자 자격 증명의 ARN"
}
