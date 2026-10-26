#!/usr/bin/env python3
"""Translate strings with the free MyMemory API (no API key required).

Reads a JSON payload from stdin:
    {"target": "es", "strings": ["Hello", "world"]}
Prints a Google-Translate-v3-shaped JSON document on stdout:
    {"translations": [{"translatedText": "Hola"}, {"translatedText": "mundo"}]}
or {"error": {"code": ..., "message": ...}} on failure.
"""

import json
import sys
import time
import urllib.parse
import urllib.request

API = "https://api.mymemory.translated.net/get"
MAX_QUERY_CHARS = 500  # MyMemory hard limit
CHUNK_CHARS = 450      # stay safely under the limit
REQUEST_PAUSE = 0.2    # be polite between chunk requests


def normalize_lang(code):
    # "en_US" / "pt-BR" -> "en" / "pt"; MyMemory expects ISO-639-1 style codes
    return (code or "en").replace("_", "-").split("-")[0].lower()


def chunk_text(text, limit=CHUNK_CHARS):
    """Split text into <=limit pieces on whitespace boundaries."""
    chunks = []
    remaining = text.strip()
    while len(remaining) > limit:
        cut = remaining.rfind(" ", 0, limit)
        if cut <= 0:
            cut = limit
        chunks.append(remaining[:cut].strip())
        remaining = remaining[cut:].strip()
    if remaining:
        chunks.append(remaining)
    return chunks or [""]


def translate_chunk(text, target):
    query = urllib.parse.urlencode({
        "q": text,
        "langpair": "Autodetect|" + target,
    })
    req = urllib.request.Request(API + "?" + query, headers={"User-Agent": "curl/8"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.load(resp)
    status = data.get("responseStatus", 0)
    if status != 200:
        details = (data.get("responseDetails") or "MyMemory error %s" % status)
        if "DISTINCT LANGUAGES" in details.upper():
            # Detected source equals the target: text is already translated
            return text
        raise RuntimeError(details)
    if data.get("quotaFinished"):
        raise RuntimeError("MyMemory daily quota exhausted; try again tomorrow")
    return data["responseData"]["translatedText"]


def main():
    payload = json.load(sys.stdin)
    target = normalize_lang(payload.get("target"))
    out = []
    try:
        for s in payload.get("strings", []):
            parts = []
            for c in chunk_text(s):
                parts.append(translate_chunk(c, target))
                time.sleep(REQUEST_PAUSE)  # pace the chunk requests
            out.append({"translatedText": " ".join(parts)})
    except Exception as e:  # surface as API error for TranslatorApi.handleApiOutput
        json.dump({"error": {"code": 500, "message": str(e)}}, sys.stdout)
        return
    json.dump({"translations": out}, sys.stdout)


if __name__ == "__main__":
    main()
