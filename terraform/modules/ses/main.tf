variable "sender_email"  {}
variable "sender_domain" {}
variable "prefix"        {}

resource "aws_ses_email_identity" "sender" {
  email = var.sender_email
}

resource "aws_ses_domain_identity" "sender" {
  count  = var.sender_domain != "" ? 1 : 0
  domain = var.sender_domain
}

resource "aws_ses_template" "notification" {
  name    = "${var.prefix}-notification"
  subject = "{{subject}}"
  html    = <<-HTML
    <!DOCTYPE html>
    <html>
      <body style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px">
        <h2 style="color:#333">{{title}}</h2>
        <p>{{body}}</p>
        <hr style="border:none;border-top:1px solid #eee;margin:20px 0"/>
        <p style="color:#999;font-size:12px">{{footer}}</p>
      </body>
    </html>
  HTML
  text    = "{{title}}\n\n{{body}}\n\n{{footer}}"
}

output "email_identity_arn" {
  value = aws_ses_email_identity.sender.arn
}
output "notification_template_name" {
  value = aws_ses_template.notification.name
}
