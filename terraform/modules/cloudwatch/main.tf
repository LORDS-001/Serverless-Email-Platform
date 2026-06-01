variable "prefix"             {}
variable "lambda_name"        {}
variable "sqs_queue_name"     {}
variable "dlq_queue_name"     {}
variable "log_retention_days" {}
variable "alarm_email"        {}
variable "aws_region"         {}

resource "aws_sns_topic" "alarms" {
  name = "${var.prefix}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.prefix}-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function has errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = var.lambda_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.prefix}-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Messages are landing in the Dead Letter Queue"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    QueueName = var.dlq_queue_name
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  alarm_name          = "${var.prefix}-queue-depth-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Email queue depth is unusually high"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.prefix}-lambda-duration-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p95"
  threshold           = 45000 
  alarm_description   = "Lambda p95 duration approaching timeout"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = var.lambda_name
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          title   = "Lambda Invocations & Errors"
          region  = var.aws_region
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_name],
            ["AWS/Lambda", "Errors",      "FunctionName", var.lambda_name],
          ]
          period = 60, stat = "Sum", view = "timeSeries"
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          title   = "Queue Depths"
          region  = var.aws_region
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.sqs_queue_name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_queue_name],
          ]
          period = 60, stat = "Average", view = "timeSeries"
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6,
        properties = {
          title   = "Lambda Duration (p50 / p95 / p99)"
          region  = var.aws_region
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_name, { stat = "p50" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_name, { stat = "p95" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_name, { stat = "p99" }],
          ]
          period = 60, view = "timeSeries"
        }
      },
    ]
  })
}

output "sns_topic_arn"    { value = aws_sns_topic.alarms.arn }
output "dashboard_name"   { value = aws_cloudwatch_dashboard.main.dashboard_name }
