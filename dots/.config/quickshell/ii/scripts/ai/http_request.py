#!/usr/bin/env python3
"""
Lightweight HTTP request helper for the Quickshell AI http_request tool.
Usage: python3 http_request.py <METHOD> <URL> [--headers JSON] [--body STRING] [--timeout N]
Returns JSON: {status, headers, body} or {error}
"""
import sys, json, argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("method", choices=["GET","POST","PUT","DELETE","PATCH"])
    parser.add_argument("url")
    parser.add_argument("--headers", default="{}", help="JSON headers object")
    parser.add_argument("--body", default="", help="Request body string")
    parser.add_argument("--timeout", type=int, default=10)
    args = parser.parse_args()

    try:
        hdrs = json.loads(args.headers) if args.headers else {}
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"Invalid headers JSON: {e}"}))
        sys.exit(1)

    try:
        import requests
        resp = requests.request(
            method=args.method,
            url=args.url,
            headers=hdrs,
            data=args.body.encode("utf-8") if args.body else None,
            timeout=args.timeout,
            allow_redirects=True,
        )
        resp_headers = dict(resp.headers)
        body = resp.text[:10240]  # cap at 10 KB
        print(json.dumps({
            "status": resp.status_code,
            "ok": resp.ok,
            "headers": resp_headers,
            "body": body,
        }))
    except ImportError:
        # Fallback: use urllib (stdlib) for GET
        import urllib.request, urllib.error
        try:
            req = urllib.request.Request(args.url, method=args.method, headers=hdrs)
            if args.body:
                req.data = args.body.encode("utf-8")
            with urllib.request.urlopen(req, timeout=args.timeout) as r:
                body = r.read(10240).decode("utf-8", errors="replace")
                print(json.dumps({
                    "status": r.status,
                    "ok": 200 <= r.status < 300,
                    "headers": dict(r.headers),
                    "body": body,
                }))
        except urllib.error.HTTPError as e:
            body = e.read(10240).decode("utf-8", errors="replace")
            print(json.dumps({"status": e.code, "ok": False, "headers": dict(e.headers), "body": body}))
        except Exception as e:
            print(json.dumps({"error": str(e)})); sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()
