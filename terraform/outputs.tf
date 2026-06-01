output "sqs_queue_url" {
  description = "URL of the main SQS queue (send messages here)"
  value       = module.sqs.queue_url
}

output "sqs_queue_arn" {
  description = "ARN of the main SQS queue"
  value       = module.sqs.queue_arn
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = module.sqs.dlq_url
}

output "lambda_function_arn" {
  description = "ARN of the email-sending Lambda function"
  value       = module.lambda.function_arn
}

output "lambda_function_name" {
  description = "Name of the email-sending Lambda function"
  value       = module.lambda.function_name
}

output "kms_key_arn" {
  description = "ARN of the KMS encryption key"
  value       = aws_kms_key.main.arn
}
