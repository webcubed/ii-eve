#!/usr/bin/env python3
"""Trash (move to trash) a Gmail message."""
import json
import sys
import urllib.request

def trash_message(access_token, message_id):
    url = f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{message_id}/trash"
    req = urllib.request.Request(url, method="POST",
        headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
        data=b"{}")
    resp = urllib.request.urlopen(req)
    return json.loads(resp.read())

def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: trash_email.py <access_token> <message_id>"}))
        sys.exit(1)

    access_token = sys.argv[1]
    message_id = sys.argv[2]

    try:
        result = trash_message(access_token, message_id)
        print(json.dumps({"success": True}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()
