output "repository_name" {
  description = "ECR 리포지토리 이름"
  value       = aws_ecr_repository.this.name
}

output "repository_arn" {
  description = "ECR 리포지토리 ARN"
  value       = aws_ecr_repository.this.arn
}

output "repository_url" {
  description = "컨테이너 이미지를 push하거나 pull할 ECR 리포지토리 URL"
  value       = aws_ecr_repository.this.repository_url
}
