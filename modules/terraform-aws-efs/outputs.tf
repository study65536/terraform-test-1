output "file_system_id" {
  description = "EFS 파일 시스템 ID"
  value       = aws_efs_file_system.this.id
  depends_on  = [aws_efs_mount_target.this, aws_vpc_security_group_ingress_rule.nfs]
}

output "file_system_arn" {
  description = "EFS 파일 시스템 ARN"
  value       = aws_efs_file_system.this.arn
}

output "dns_name" {
  description = "EFS 파일 시스템 마운트 DNS 이름"
  value       = aws_efs_file_system.this.dns_name
  depends_on  = [aws_efs_mount_target.this, aws_vpc_security_group_ingress_rule.nfs]
}

output "security_group_id" {
  description = "EFS 마운트 대상 보안 그룹 ID"
  value       = aws_security_group.mount_targets.id
}

output "mount_target_ids" {
  description = "가용 영역별 EFS 마운트 대상 ID"
  value       = { for az, target in aws_efs_mount_target.this : az => target.id }
}
