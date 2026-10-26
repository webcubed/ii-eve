#!/usr/bin/env python3
"""
Web search and fetch helper for Quickshell AI.
Supports Exa API (if EXA_API_KEY is configured) and DuckDuckGo (zero-config fallback).
"""
import sys
import json
import os
import re
import urllib.parse

USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

def get_exa_key():
    key = os.environ.get("EXA_API_KEY", "").strip()
    if key:
        return key
    cfg_path = os.path.expanduser("~/.config/illogical-impulse/config.json")
    if os.path.exists(cfg_path):
        try:
            with open(cfg_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("ai", {}).get("exaApiKey", "").strip()
        except Exception:
            pass
    return ""

def search_exa(term, count, api_key):
    import requests
    headers = {
        "x-api-key": api_key,
        "Content-Type": "application/json",
        "User-Agent": USER_AGENT
    }
    payload = {
        "query": term,
        "numResults": count,
        "useAutoprompt": True
    }
    resp = requests.post("https://api.exa.ai/search", json=payload, headers=headers, timeout=15)
    if resp.status_code != 200:
        raise RuntimeError(f"Exa search error {resp.status_code}: {resp.text[:200]}")
    data = resp.json()
    results = []
    for item in data.get("results", []):
        results.append({
            "title": item.get("title", ""),
            "url": item.get("url", ""),
            "snippet": item.get("text", "") or item.get("snippet", "")
        })
    return {"engine": "exa", "results": results}

def search_duckduckgo(term, count):
    import requests
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5"
    }
    resp = requests.post(
        "https://html.duckduckgo.com/html/",
        data={"q": term},
        headers=headers,
        timeout=15
    )
    if resp.status_code != 200:
        raise RuntimeError(f"DuckDuckGo returned status {resp.status_code}")

    html = resp.text
    results = []
    # Match result blocks: class="result results_links results_links_deep web-result"
    blocks = re.findall(r'<div[^>]*class="[^"]*result results_links[^"]*"[^>]*>(.*?)</div>\s*</div>', html, re.DOTALL)
    if not blocks:
        blocks = re.findall(r'<div[^>]*class="[^"]*web-result[^"]*"[^>]*>(.*?)</div>\s*</div>', html, re.DOTALL)

    for block in blocks:
        title_match = re.search(r'<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>', block, re.DOTALL)
        snippet_match = re.search(r'<a[^>]*class="result__snippet"[^>]*>(.*?)</a>', block, re.DOTALL)
        if not title_match:
            continue

        raw_url = title_match.group(1)
        # Parse unquoted duckduckgo redirect if present: /l/?uddg=...
        if "uddg=" in raw_url:
            parsed = urllib.parse.parse_qs(urllib.parse.urlparse(raw_url).query)
            clean_url = parsed.get("uddg", [raw_url])[0]
        else:
            clean_url = raw_url

        title = re.sub(r'<[^>]+>', '', title_match.group(2)).strip()
        snippet = re.sub(r'<[^>]+>', '', snippet_match.group(1)).strip() if snippet_match else ""

        if clean_url and title:
            results.append({
                "title": title,
                "url": clean_url,
                "snippet": snippet
            })
        if len(results) >= count:
            break

    if not results:
        # Fallback regex if class names shifted
        raw_links = re.findall(r'<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>', html, re.DOTALL)
        for href, raw_title in raw_links[:count]:
            clean_title = re.sub(r'<[^>]+>', '', raw_title).strip()
            if "uddg=" in href:
                parsed = urllib.parse.parse_qs(urllib.parse.urlparse(href).query)
                clean_href = parsed.get("uddg", [href])[0]
            else:
                clean_href = href
            results.append({
                "title": clean_title,
                "url": clean_href,
                "snippet": ""
            })

    return {"engine": "duckduckgo", "results": results[:count]}

def do_search(term, count):
    exa_key = get_exa_key()
    if exa_key:
        try:
            return search_exa(term, count, exa_key)
        except Exception as e:
            sys.stderr.write(f"Exa search failed, falling back to DuckDuckGo: {e}\n")

    return search_duckduckgo(term, count)

def do_fetch(url):
    import requests
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    }
    resp = requests.get(url, headers=headers, timeout=15)
    if resp.status_code != 200:
        return {"error": f"Failed to fetch {url}: HTTP {resp.status_code}", "url": url}

    html = resp.text
    # Extract title
    title_match = re.search(r'<title[^>]*>(.*?)</title>', html, re.IGNORECASE | re.DOTALL)
    title = re.sub(r'<[^>]+>', '', title_match.group(1)).strip() if title_match else url

    # Strip scripts, styles, headers, navs, footers
    cleaned = re.sub(r'<(script|style|nav|header|footer|aside)[^>]*>.*?</\1>', '', html, flags=re.IGNORECASE | re.DOTALL)
    # Strip remaining tags
    text = re.sub(r'<[^>]+>', ' ', cleaned)
    # Unescape html entities
    text = text.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>').replace('&quot;', '"')
    # Collapse whitespace
    text = re.sub(r'\s+', ' ', text).strip()

    return {
        "url": url,
        "title": title,
        "content": text[:6000]
    }

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: web.py search <term> [count] | web.py fetch <url>"}))
        sys.exit(1)

    cmd = sys.argv[1]
    try:
        if cmd == "search":
            term = sys.argv[2] if len(sys.argv) > 2 else ""
            count = int(sys.argv[3]) if len(sys.argv) > 3 else 5
            result = do_search(term, count)
            print(json.dumps(result))
        elif cmd == "fetch":
            url = sys.argv[2] if len(sys.argv) > 2 else ""
            result = do_fetch(url)
            print(json.dumps(result))
        else:
            print(json.dumps({"error": f"Unknown command: {cmd}"}))
            sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e), "results": []}))

if __name__ == "__main__":
    main()
