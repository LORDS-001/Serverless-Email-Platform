variable "prefix"             {}
variable "lambda_role_arn"    {}
variable "sqs_queue_arn"      {}
variable "sender_email"       {}
variable "timeout"            {}
variable "memory_size"        {}
variable "batch_size"         {}
variable "kms_key_arn"        {}
variable "log_retention_days" {}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/src"
  output_path = "${path.module}/lambda_package.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.prefix}-email-sender"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

resource "aws_lambda_function" "email_sender" {
  function_name    = "${var.prefix}-email-sender"
  role             = var.lambda_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = var.timeout
  memory_size      = var.memory_size
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  kms_key_arn = var.kms_key_arn

  environment {
    variables = {
      SENDER_EMAIL = var.sender_email
      LOG_LEVEL    = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.email_sender.arn
  batch_size       = var.batch_size

  function_response_types = ["ReportBatchItemFailures"]
}

output "function_name" { value = aws_lambda_function.email_sender.function_name }
output "function_arn"  { value = aws_lambda_function.email_sender.arn }
