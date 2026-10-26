#!/usr/bin/env python3
"""Send email via Gmail API."""
import base64
import json
import sys
import urllib.parse
import urllib.request
from email.mime.text import MIMEText

def get_credentials():
    client_id = os.environ.get("GMAIL_CLIENT_ID", "")
    client_secret = os.environ.get("GMAIL_CLIENT_SECRET", "")
    config_path = os.path.expanduser("~/.config/illogical-impulse/config.json")
    if os.path.exists(config_path):
        try:
            with open(config_path) as f:
                cfg = json.load(f)
            api_keys = cfg.get("apiKeys", {})
            if not client_id:
                client_id = api_keys.get("gmail_client_id", "")
            if not client_secret:
                client_secret = api_keys.get("gmail_client_secret", "")
        except Exception:
            pass
    return client_id, client_secret

def refresh_access_token(refresh_token):
    client_id, client_secret = get_credentials()
    data = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token"
    }).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
    resp = urllib.request.urlopen(req)
    return json.loads(resp.read()).get("access_token", "")

def send_email(access_token, to, subject, body):
    msg = MIMEText(body)
    msg["to"] = to
    msg["subject"] = subject
    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()

    data = json.dumps({"raw": raw}).encode()
    req = urllib.request.Request(
        "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
        data=data,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        },
        method="POST"
    )
    resp = urllib.request.urlopen(req)
    return json.loads(resp.read())

def main():
    if len(sys.argv) < 5:
        print(json.dumps({"success": False, "error": "Usage: send_email.py <refresh_token> <to> <subject> <body>"}))
        sys.exit(1)

    refresh_token = sys.argv[1]
    to = sys.argv[2]
    subject = sys.argv[3]
    body = sys.argv[4]

    try:
        access_token = refresh_access_token(refresh_token)
        result = send_email(access_token, to, subject, body)
        print(json.dumps({"success": True, "id": result.get("id", "")}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()
