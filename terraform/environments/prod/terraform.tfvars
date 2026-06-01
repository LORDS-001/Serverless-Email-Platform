environment   = "prod"
aws_region    = "us-east-1"
sender_email  = "no-reply@yourdomain.com"   
sender_domain = "yourdomain.com"            

sqs_visibility_timeout = 300
sqs_message_retention  = 86400
dlq_max_receive_count  = 3
lambda_timeout         = 60
lambda_memory          = 512
lambda_batch_size      = 10
log_retention_days     = 90
alarm_email            = "ops-team@yourdomain.com"  
