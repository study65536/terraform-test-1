output "volume_id" {
  description = "EBS 볼륨 ID"
  value       = aws_ebs_volume.this.id
}

output "volume_arn" {
  description = "EBS 볼륨 ARN"
  value       = aws_ebs_volume.this.arn
}
