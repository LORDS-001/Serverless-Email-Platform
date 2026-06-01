variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as a prefix for all resources"
  type        = string
  default     = "email-platform"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
}

variable "sender_email" {
  description = "Verified SES sender email address"
  type        = string
}

variable "sender_domain" {
  description = "Verified SES sender domain (optional – used when doing domain-level verification)"
  type        = string
  default     = ""
}

variable "sqs_visibility_timeout" {
  description = "SQS visibility timeout in seconds (must be >= Lambda timeout)"
  type        = number
  default     = 300
}

variable "sqs_message_retention" {
  description = "SQS message retention period in seconds"
  type        = number
  default     = 86400
}

variable "dlq_max_receive_count" {
  description = "Number of receive attempts before a message is sent to the DLQ"
  type        = number
  default     = 3
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60                                                                                                                                                                                                                                                                                                                                                                                                                                  
}

variable "lambda_memory" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 256
}

variable "lambda_batch_size" {
  description = "Number of SQS messages per Lambda invocation"
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  default     = ""
}
