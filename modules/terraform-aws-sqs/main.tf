locals {
  suffix = var.fifo ? ".fifo" : ""
}

resource "aws_sqs_queue" "this" {
  name                        = "${var.name}${local.suffix}"
  fifo_queue                  = var.fifo
  content_based_deduplication = var.fifo ? var.content_based_deduplication : null
  sqs_managed_sse_enabled     = true
  visibility_timeout_seconds  = var.visibility_timeout_seconds
  message_retention_seconds   = var.message_retention_seconds
  receive_wait_time_seconds   = 20
  tags                        = var.tags
}

resource "aws_sqs_queue" "dead_letter" {
  count = var.max_receive_count == null ? 0 : 1

  name                        = "${var.name}-dlq${local.suffix}"
  fifo_queue                  = var.fifo
  content_based_deduplication = var.fifo ? var.content_based_deduplication : null
  sqs_managed_sse_enabled     = true
  message_retention_seconds   = 1209600
  tags                        = var.tags
}

resource "aws_sqs_queue_redrive_allow_policy" "this" {
  count = var.max_receive_count == null ? 0 : 1

  queue_url = aws_sqs_queue.dead_letter[0].url
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}

resource "aws_sqs_queue_redrive_policy" "this" {
  count = var.max_receive_count == null ? 0 : 1

  queue_url = aws_sqs_queue.this.url
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter[0].arn
    maxReceiveCount     = var.max_receive_count
  })

  depends_on = [aws_sqs_queue_redrive_allow_policy.this]
}
