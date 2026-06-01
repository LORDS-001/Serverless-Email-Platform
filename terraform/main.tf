locals {
  prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid    = "RootAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "main" {
  description             = "${local.prefix} encryption key"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_policy.json
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.prefix}"
  target_key_id = aws_kms_key.main.key_id
}

module "sqs" {
  source = "./modules/sqs"

  prefix                 = local.prefix
  kms_key_id             = aws_kms_key.main.id
  visibility_timeout     = var.sqs_visibility_timeout
  message_retention      = var.sqs_message_retention
  dlq_max_receive_count  = var.dlq_max_receive_count
}

module "iam" {
  source = "./modules/iam"

  prefix        = local.prefix
  sqs_queue_arn = module.sqs.queue_arn
  dlq_arn       = module.sqs.dlq_arn
  kms_key_arn   = aws_kms_key.main.arn
}

module "ses" {
  source = "./modules/ses"

  sender_email  = var.sender_email
  sender_domain = var.sender_domain
  prefix        = local.prefix
}

module "lambda" {
  source = "./modules/lambda"

  prefix            = local.prefix
  lambda_role_arn   = module.iam.lambda_role_arn
  sqs_queue_arn     = module.sqs.queue_arn
  sender_email      = var.sender_email
  timeout           = var.lambda_timeout
  memory_size       = var.lambda_memory
  batch_size        = var.lambda_batch_size
  kms_key_arn       = aws_kms_key.main.arn
  log_retention_days = var.log_retention_days
}

module "cloudwatch" {
  source = "./modules/cloudwatch"

  prefix             = local.prefix
  lambda_name        = module.lambda.function_name
  sqs_queue_name     = module.sqs.queue_name
  dlq_queue_name     = module.sqs.dlq_name
  log_retention_days = var.log_retention_days
  alarm_email        = var.alarm_email
  aws_region         = var.aws_region 
}
