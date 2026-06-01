"""
Email Sender Lambda
Consumes SQS messages and sends emails via SES.

Expected SQS message body (JSON):
{
    "to": "recipient@example.com",          # required  (or list)
    "subject": "Hello",                     # required
    "body_html": "<p>Hello</p>",            # optional (use either body_html or body_text)
    "body_text": "Hello",                   # optional
    "reply_to": "support@example.com",      # optional
    "cc": ["cc@example.com"],               # optional
    "bcc": ["bcc@example.com"]              # optional
}
"""

import json
import logging
import os
from typing import Any

import boto3
from botocore.exceptions import ClientError

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL, format="%(levelname)s %(name)s %(message)s")
logger = logging.getLogger(__name__)

SENDER_EMAIL = os.environ["SENDER_EMAIL"]

ses = boto3.client("ses")

def _parse_message(raw_body: str) -> dict:
    """Parse and validate the SQS message body."""
    try:
        data = json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Message body is not valid JSON: {exc}") from exc

    # Normalise 'to' to a list
    to = data.get("to")
    if isinstance(to, str):
        data["to"] = [to]
    elif not isinstance(to, list):
        raise ValueError("'to' must be a string or list of strings")

    if not data.get("subject"):
        raise ValueError("'subject' is required")

    if not data.get("body_html") and not data.get("body_text"):
        raise ValueError("At least one of 'body_html' or 'body_text' is required")

    return data

def _build_destination(msg: dict) -> dict:
    dest: dict[str, Any] = {"ToAddresses": msg["to"]}
    if msg.get("cc"):
        dest["CcAddresses"] = msg["cc"] if isinstance(msg["cc"], list) else [msg["cc"]]
    if msg.get("bcc"):
        dest["BccAddresses"] = msg["bcc"] if isinstance(msg["bcc"], list) else [msg["bcc"]]
    return dest


def _build_message(msg: dict) -> dict:
    body: dict[str, Any] = {}
    if msg.get("body_html"):
        body["Html"] = {"Data": msg["body_html"], "Charset": "UTF-8"}
    if msg.get("body_text"):
        body["Text"] = {"Data": msg["body_text"], "Charset": "UTF-8"}

    return {
        "Subject": {"Data": msg["subject"], "Charset": "UTF-8"},
        "Body": body,
    }


def send_email(msg: dict) -> str:
    """Send one email via SES. Returns the SES MessageId."""
    kwargs: dict[str, Any] = {
        "Source": SENDER_EMAIL,
        "Destination": _build_destination(msg),
        "Message": _build_message(msg),
    }
    if msg.get("reply_to"):
        reply = msg["reply_to"]
        kwargs["ReplyToAddresses"] = [reply] if isinstance(reply, str) else reply

    response = ses.send_email(**kwargs)
    return response["MessageId"]


def lambda_handler(event: dict, context: Any) -> dict:
    """
    Process a batch of SQS records.
    Uses ReportBatchItemFailures so only failed records are retried.
    """
    failures: list[dict] = []

    for record in event.get("Records", []):
        message_id = record["messageId"]
        try:
            msg = _parse_message(record["body"])
            ses_id = send_email(msg)
            logger.info(
                "Email sent",
                extra={
                    "sqs_message_id": message_id,
                    "ses_message_id": ses_id,
                    "to": msg["to"],
                    "subject": msg["subject"],
                },
            )
        except ClientError as exc:
            error_code = exc.response["Error"]["Code"]
            logger.error(
                "SES error for message %s: %s – %s",
                message_id,
                error_code,
                exc.response["Error"]["Message"],
            )
            failures.append({"itemIdentifier": message_id})
        except ValueError as exc:
            logger.error("Malformed message %s discarded: %s", message_id, exc)
        except Exception as exc: 
            logger.exception("Unexpected error processing message %s: %s", message_id, exc)
            failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": failures}
