#!/usr/bin/env python3
"""Gmail OAuth2 server - opens browser for auth, returns refresh token via IPC."""
import http.server
import json
import os
import sys
import threading
import urllib.parse
import urllib.request

REDIRECT_URI = "http://localhost:19876/callback"
SCOPES = "https://mail.google.com/"

def get_credentials():
    """Load client ID/secret from keyring config or environment."""
    client_id = os.environ.get("GMAIL_CLIENT_ID", "")
    client_secret = os.environ.get("GMAIL_CLIENT_SECRET", "")
    # Try reading from quickshell keyring config
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

class AuthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/callback":
            params = urllib.parse.parse_qs(parsed.query)
            code = params.get("code", [None])[0]
            if code:
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(b"<h1>Authenticated! You can close this window.</h1>")
                # Exchange code for tokens
                threading.Thread(target=exchange_code, args=(code,), daemon=True).start()
            else:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"Missing code parameter")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress logs

def exchange_code(code):
    client_id, client_secret = get_credentials()
    data = urllib.parse.urlencode({
        "code": code,
        "client_id": client_id,
        "client_secret": client_secret,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code"
    }).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
    try:
        resp = urllib.request.urlopen(req)
        tokens = json.loads(resp.read())
        refresh_token = tokens.get("refresh_token", "")
        access_token = tokens.get("access_token", "")
        expires_in = tokens.get("expires_in", 3600)
        # Get user info
        user_email = ""
        user_avatar = ""
        try:
            req2 = urllib.request.Request("https://www.googleapis.com/oauth2/v2/userinfo",
                headers={"Authorization": f"Bearer {access_token}"})
            resp2 = urllib.request.urlopen(req2)
            user_info = json.loads(resp2.read())
            user_email = user_info.get("email", "")
            user_avatar = user_info.get("picture", "")
        except Exception:
            pass
        # Output result as JSON for quickshell IPC
        result = json.dumps({
            "refresh_token": refresh_token,
            "email": user_email,
            "avatar": user_avatar
        })
        print(result, flush=True)
    except Exception as e:
        print(json.dumps({"error": str(e)}), flush=True)

def main():
    client_id, client_secret = get_credentials()
    if not client_id or not client_secret:
        print(json.dumps({"error": "Gmail credentials not configured. Set GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET environment variables or add them to config.json apiKeys."}))
        sys.exit(1)

    auth_params = urllib.parse.urlencode({
        "client_id": client_id,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": SCOPES,
        "access_type": "offline",
        "prompt": "consent"
    })
    auth_url = f"https://accounts.google.com/o/oauth2/v2/auth?{auth_params}"
    print(f"Opening browser for authentication...")
    import webbrowser
    webbrowser.open(auth_url)

    server = http.server.HTTPServer(("localhost", 19876), AuthHandler)
    server.handle_request()  # Handle one request then exit

if __name__ == "__main__":
    main()
