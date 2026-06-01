variable "prefix"                {}
variable "kms_key_id"            {}
variable "visibility_timeout"    {}
variable "message_retention"     {}
variable "dlq_max_receive_count" {}

resource "aws_sqs_queue" "dlq" {
  name                       = "${var.prefix}-email-dlq"
  kms_master_key_id          = var.kms_key_id
  message_retention_seconds  = 1209600
}

resource "aws_sqs_queue" "main" {
  name                       = "${var.prefix}-email-queue"
  kms_master_key_id          = var.kms_key_id
  visibility_timeout_seconds = var.visibility_timeout
  message_retention_seconds  = var.message_retention

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.dlq_max_receive_count
  })
}

output "queue_url"  { value = aws_sqs_queue.main.id }
output "queue_arn"  { value = aws_sqs_queue.main.arn }
output "queue_name" { value = aws_sqs_queue.main.name }
output "dlq_url"    { value = aws_sqs_queue.dlq.id }
output "dlq_arn"    { value = aws_sqs_queue.dlq.arn }
output "dlq_name"   { value = aws_sqs_queue.dlq.name }
