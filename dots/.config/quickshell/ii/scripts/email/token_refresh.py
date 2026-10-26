#!/usr/bin/env python3
"""Refresh Gmail OAuth2 access token."""
import json
import os
import sys
import urllib.parse
import urllib.request

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

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: token_refresh.py <refresh_token>"}))
        sys.exit(1)

    refresh_token = sys.argv[1]
    client_id, client_secret = get_credentials()

    if not client_id or not client_secret:
        print(json.dumps({"error": "Gmail credentials not configured"}))
        sys.exit(1)

    data = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token"
    }).encode()

    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
    try:
        resp = urllib.request.urlopen(req)
        tokens = json.loads(resp.read())
        print(json.dumps({
            "access_token": tokens.get("access_token", ""),
            "expires_in": tokens.get("expires_in", 3600),
            "token_type": tokens.get("token_type", "Bearer")
        }))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()
