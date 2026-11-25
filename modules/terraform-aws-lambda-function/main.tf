terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.100"
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name     = var.name
  role              = var.execution_role_arn
  s3_bucket         = var.package.bucket
  s3_key            = var.package.key
  s3_object_version = var.package.version
  handler           = var.handler
  runtime           = var.runtime
  memory_size       = var.memory_mb
  timeout           = var.timeout_seconds
  publish           = true
  tags              = var.tags

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [var.environment_variables] : []
    content {
      variables = environment.value
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]
}
