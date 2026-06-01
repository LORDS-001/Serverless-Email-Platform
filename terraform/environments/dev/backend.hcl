# Pass this file to terraform init:
#   terraform init -backend-config=environments/dev/backend.hcl
bucket         = "my-terraform-test-081017"
key            = "email-platform/dev/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
