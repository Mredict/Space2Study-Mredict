"""
AWS Lambda function: CloudWatch Alarm / SNS to Discord Webhook Forwarder.
Translates Amazon SNS CloudWatch Alarm notifications into formatted Discord embeds.
"""

import json
import logging
import os
import urllib.request
import urllib.error

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

DISCORD_WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL")

# Discord Color Constants (Decimal)
COLOR_ALARM = 15158332  # Crimson Red (#E74C3C)
COLOR_OK = 3066993      # Emerald Green (#2ECC71)
COLOR_UNKNOWN = 9807270 # Steel Gray (#95A5A6)

# Status Badge Icons
EMOJI_ALARM = "🚨"
EMOJI_OK = "✅"
EMOJI_INFO = "ℹ️"


def lambda_handler(event, context):
    if not DISCORD_WEBHOOK_URL:
        logger.error("DISCORD_WEBHOOK_URL environment variable is not configured.")
        return {"statusCode": 500, "body": "Configuration missing"}

    for record in event.get("Records", []):
        raw_message = record.get("Sns", {}).get("Message", "")
        subject = record.get("Sns", {}).get("Subject", "AWS CloudWatch Alert")

        logger.info("Received SNS Message payload: %s", raw_message)

        # Parse SNS JSON payload or fall back to plain text
        try:
            message_data = json.loads(raw_message)
        except (ValueError, TypeError):
            message_data = {
                "AlarmName": subject,
                "NewStateValue": "INFO",
                "NewStateReason": raw_message,
                "Region": "eu-central-1"
            }

        alarm_name = message_data.get("AlarmName", "Unknown Alarm")
        new_state = message_data.get("NewStateValue", "UNKNOWN").upper()
        reason = message_data.get("NewStateReason", "No trigger details provided.")
        region = message_data.get("Region", "eu-central-1")
        timestamp = message_data.get("StateChangeTime", "")

        # Select styling based on state
        if new_state == "ALARM":
            color = COLOR_ALARM
            badge = EMOJI_ALARM
        elif new_state == "OK":
            color = COLOR_OK
            badge = EMOJI_OK
        else:
            color = COLOR_UNKNOWN
            badge = EMOJI_INFO

        payload = {
            "username": "AWS CloudWatch Monitor",
            "avatar_url": "https://a.b.cdn.console.awsstatic.com/a/v1/E4EFA5U5QZBL5JICUUP47S7QG3PZ6OQY/favicon.ico",
            "embeds": [
                {
                    "title": f"{badge} [{new_state}] {alarm_name}",
                    "description": reason,
                    "color": color,
                    "fields": [
                        {
                            "name": "State",
                            "value": f"`{new_state}`",
                            "inline": True
                        },
                        {
                            "name": "Region",
                            "value": f"`{region}`",
                            "inline": True
                        }
                    ],
                    "footer": {
                        "text": f"Space2Study Monitoring • {timestamp}" if timestamp else "Space2Study Monitoring"
                    }
                }
            ]
        }

        # Dispatch HTTP POST request to Discord
        req = urllib.request.Request(
            url=DISCORD_WEBHOOK_URL,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "User-Agent": "AWS-Lambda-Discord-Notifier/1.0"
            },
            method="POST"
        )

        try:
            with urllib.request.urlopen(req) as response:
                logger.info("Alert dispatched to Discord. Status code: %s", response.status)
        except urllib.error.HTTPError as err:
            logger.error("Discord API rejected message: HTTP %d: %s", err.code, err.read().decode())
        except Exception as err:
            logger.error("Failed to post message to Discord: %s", str(err))

    return {"statusCode": 200, "body": "Alert processed"}