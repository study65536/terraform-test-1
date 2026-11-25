output "arn" {
  value      = aws_iam_role.this.arn
  depends_on = [aws_iam_role_policy.inline, aws_iam_role_policy_attachment.managed]
}
output "name" {
  value = aws_iam_role.this.name
}
