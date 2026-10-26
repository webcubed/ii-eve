#!/usr/bin/env python3
"""Fetch emails from Gmail API."""
import json
import sys
import urllib.parse
import urllib.request

def fetch_emails(access_token, label="INBOX", max_results=20):
    url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages?labelIds={label}&maxResults={max_results}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {access_token}"})

    try:
        resp = urllib.request.urlopen(req)
        data = json.loads(resp.read())
        message_ids = [m["id"] for m in data.get("messages", [])]

        messages = []
        for mid in message_ids:
            msg_req = urllib.request.Request(
                f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{mid}?format=metadata",
                headers={"Authorization": f"Bearer {access_token}"}
            )
            msg_resp = urllib.request.urlopen(msg_req)
            msg_data = json.loads(msg_resp.read())

            headers = {h["name"].lower(): h["value"] for h in msg_data.get("payload", {}).get("headers", [])}
            labels = msg_data.get("labelIds", [])

            messages.append({
                "id": mid,
                "threadId": msg_data.get("threadId", ""),
                "subject": headers.get("subject", "(no subject)"),
                "from": headers.get("from", ""),
                "date": headers.get("date", ""),
                "snippet": msg_data.get("snippet", ""),
                "unread": "UNREAD" in labels,
                "starred": "STARRED" in labels,
                "timestamp": _parse_date(headers.get("date", ""))
            })

        return {"messages": messages, "historyId": data.get("historyId", "")}
    except Exception as e:
        return {"error": str(e), "messages": []}

def _parse_date(date_str):
    """Best-effort parse of RFC 2822 date to epoch seconds."""
    from email.utils import parsedate_to_datetime
    try:
        return int(parsedate_to_datetime(date_str).timestamp())
    except Exception:
        return 0

def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: fetch_emails.py <access_token> <label> [max_results]"}))
        sys.exit(1)

    access_token = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else "INBOX"
    max_results = int(sys.argv[3]) if len(sys.argv) > 3 else 20

    result = fetch_emails(access_token, label, max_results)
    print(json.dumps(result))

if __name__ == "__main__":
    main()
