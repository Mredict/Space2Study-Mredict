import json
import os
import urllib.request

WEBHOOK_URL = os.environ["DISCORD_WEBHOOK_URL"]


def lambda_handler(event, context):
    for record in event.get("Records", []):
        message = record["Sns"]["Message"]
        subject = record["Sns"].get("Subject", "AWS Alert")

        try:
            parsed = json.loads(message)
            alarm_name = parsed.get("AlarmName", subject)
            new_state = parsed.get("NewStateValue", "")
            reason = parsed.get("NewStateReason", message)
            content = f"**{alarm_name}** -> `{new_state}`\n{reason}"
        except (json.JSONDecodeError, TypeError):
            content = f"**{subject}**\n{message}"

        body = json.dumps({"content": content[:2000]}).encode("utf-8")
        req = urllib.request.Request(
            WEBHOOK_URL, data=body, headers={"Content-Type": "application/json"}
        )
        try:
            urllib.request.urlopen(req, timeout=10)
        except Exception as exc:
            print(f"Discord post failed: {exc}")

    return {"statusCode": 200}
