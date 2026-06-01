"""Unit tests for the email sender Lambda."""

import json
from unittest.mock import MagicMock, patch

import pytest

import os
os.environ["SENDER_EMAIL"] = "test@example.com"

from handler import lambda_handler, _parse_message, send_email


class TestParseMessage:
    def test_valid_html_message(self):
        body = json.dumps({"to": "a@b.com", "subject": "Hi", "body_html": "<p>Hi</p>"})
        msg = _parse_message(body)
        assert msg["to"] == ["a@b.com"]

    def test_to_list_normalised(self):
        body = json.dumps({"to": ["a@b.com", "c@d.com"], "subject": "Hi", "body_text": "Hi"})
        msg = _parse_message(body)
        assert len(msg["to"]) == 2

    def test_missing_subject_raises(self):
        body = json.dumps({"to": "a@b.com", "body_text": "Hi"})
        with pytest.raises(ValueError, match="subject"):
            _parse_message(body)

    def test_missing_body_raises(self):
        body = json.dumps({"to": "a@b.com", "subject": "Hi"})
        with pytest.raises(ValueError, match="body"):
            _parse_message(body)

    def test_invalid_json_raises(self):
        with pytest.raises(ValueError, match="not valid JSON"):
            _parse_message("not-json")


def _make_record(body: dict, message_id: str = "msg-1") -> dict:
    return {"messageId": message_id, "body": json.dumps(body)}


@patch("handler.ses")
class TestLambdaHandler:
    def _good_body(self):
        return {"to": "r@example.com", "subject": "Test", "body_text": "Hello"}

    def test_successful_send(self, mock_ses):
        mock_ses.send_email.return_value = {"MessageId": "ses-001"}
        event = {"Records": [_make_record(self._good_body())]}
        result = lambda_handler(event, None)
        assert result == {"batchItemFailures": []}
        mock_ses.send_email.assert_called_once()

    def test_ses_throttle_returns_failure(self, mock_ses):
        from botocore.exceptions import ClientError
        mock_ses.send_email.side_effect = ClientError(
            {"Error": {"Code": "Throttling", "Message": "Rate exceeded"}},
            "SendEmail",
        )
        event = {"Records": [_make_record(self._good_body(), "msg-fail")]}
        result = lambda_handler(event, None)
        assert result == {"batchItemFailures": [{"itemIdentifier": "msg-fail"}]}

    def test_malformed_message_discarded(self, mock_ses):
        """Malformed messages should be dropped (not retried) – no batch failure."""
        event = {"Records": [{"messageId": "bad-1", "body": "not-json"}]}
        result = lambda_handler(event, None)
        assert result == {"batchItemFailures": []}
        mock_ses.send_email.assert_not_called()

    def test_partial_batch_failure(self, mock_ses):
        from botocore.exceptions import ClientError
        mock_ses.send_email.side_effect = [
            {"MessageId": "ses-001"},  
            ClientError(                
                {"Error": {"Code": "Throttling", "Message": "Rate exceeded"}},
                "SendEmail",
            ),
        ]
        event = {
            "Records": [
                _make_record(self._good_body(), "msg-ok"),
                _make_record(self._good_body(), "msg-fail"),
            ]
        }
        result = lambda_handler(event, None)
        assert result == {"batchItemFailures": [{"itemIdentifier": "msg-fail"}]}
