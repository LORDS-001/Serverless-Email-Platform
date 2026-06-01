# Serverless Email Notification Platform

Event-driven email system: **SQS → Lambda → SES**, all provisioned with Terraform.

## Architecture

```
Application
    │
    ▼
SQS Queue (encrypted, KMS)
    │
    ├─► Lambda (Python 3.12, ReportBatchItemFailures)
    │       │
    │       └─► AWS SES ──► End User Email
    │
    └─► Dead Letter Queue (after 3 failed attempts)
            │
            └─► CloudWatch Alarm ──► SNS ──► Ops Email
```

## Repository Structure

```
email-platform/
├── lambda/
│   ├── src/handler.py          # Lambda function
│   └── tests/test_handler.py   # Unit tests
└── terraform/
    ├── main.tf                 # Root module – wires everything together
    ├── variables.tf
    ├── outputs.tf
    ├── provider.tf
    ├── modules/
    │   ├── sqs/                # Main queue + DLQ + redrive policy
    │   ├── lambda/             # Function, log group, ESM
    │   ├── ses/                # Email identity + templates
    │   ├── iam/                # Execution role (least-privilege)
    │   └── cloudwatch/         # Alarms, dashboard, SNS
    └── environments/
        ├── dev/
        └── prod/
```

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | ≥ 1.5 |
| Python | 3.12 |
| AWS CLI | v2 |

## First-time Setup

### 1. Verify your SES sender identity

```bash
# Email-level (sandbox)
aws ses verify-email-identity --email-address no-reply@yourdomain.com

# Domain-level (production – requires DNS TXT record)
aws ses verify-domain-identity --domain yourdomain.com
```

> **Note:** New AWS accounts start in SES sandbox. Request production access via the AWS console before going live.

### 2. Create the Terraform state bucket (once per account)

```bash
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

### 3. Update configuration

Edit `terraform/environments/dev/terraform.tfvars`:
- Set `sender_email` to your verified address
- Set `alarm_email` to receive operational alerts
- Update `backend.hcl` with your S3 bucket name

## Deploy

```bash
cd terraform

# Dev
terraform init -backend-config=environments/dev/backend.hcl
terraform plan  -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars

# Prod
terraform init  -backend-config=environments/prod/backend.hcl -reconfigure
terraform plan  -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars
```

## Send a Test Email

After deployment, grab the queue URL from the Terraform output and send a test message:

```bash
QUEUE_URL=$(terraform output -raw sqs_queue_url)

aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{
    "to": "you@example.com",
    "subject": "Hello from the email platform",
    "body_html": "<h1>It works!</h1>",
    "body_text": "It works!"
  }'
```

## Message Format

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `to` | string or string[] | ✅ | Recipient(s) |
| `subject` | string | ✅ | Email subject |
| `body_html` | string | one of | HTML body |
| `body_text` | string | one of | Plain-text body |
| `reply_to` | string or string[] | — | Reply-To addresses |
| `cc` | string[] | — | CC addresses |
| `bcc` | string[] | — | BCC addresses |

## Run Tests

```bash
pip install pytest boto3 botocore
pytest lambda/tests/ -v
```

## CI/CD

The GitHub Actions workflow (`.github/workflows/terraform.yml`) runs on every push/PR:

1. **Lint** – `ruff` (Python) + `terraform fmt`
2. **Validate** – `terraform validate`
3. **Plan** – posts plan diff as a PR comment
4. **Apply dev** – auto-applies on merge to `main`
5. **Apply prod** – requires manual approval in GitHub Environments

Set these repository secrets:
- `AWS_ROLE_ARN_DEV` – IAM role ARN for dev deploys (OIDC)
- `AWS_ROLE_ARN_PROD` – IAM role ARN for prod deploys (OIDC)

## Monitoring

| Alarm | Trigger |
|-------|---------|
| `lambda-errors` | Any Lambda error |
| `dlq-not-empty` | Any message in DLQ |
| `queue-depth-high` | >1,000 messages waiting |
| `lambda-duration-high` | p95 duration >45 s |

CloudWatch dashboard: `{project}-{env}-overview`

## Teardown

```bash
terraform destroy -var-file=environments/dev/terraform.tfvars
```
