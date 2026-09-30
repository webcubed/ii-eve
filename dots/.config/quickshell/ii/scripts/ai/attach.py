#!/usr/bin/env python3
"""
The one place that turns a path into bytes for an AI request.

Invoked as `python3 attach.py <command> ...`; stdout is the reply.

  probe <path>                                metadata for the attachment pipeline
  extract <path>                              document text, as JSON
  inject <body> <spec>                        write attachments into a request body
  search <rootsJson> <query> <limit> <kinds>  filename search inside opted-in roots
  peek <path> <maxChars>                      bounded preview for files_preview/attach

probe / extract / search / peek always print JSON: `{"error": ...}` on failure,
never nothing — an empty stdout makes the QML side fall back to the generic
"Could not read that file." inject prints a human message and exits non-zero;
the generated request script (AiRequest.buildScript) turns that into
`@@II_ATTACHMENT_ERROR:` on the wire.

`canonical_root` here matches `canonicalRoot` in AiFilesIntegration.qml so the
two never disagree about what counts as "inside" a configured root.
"""

import base64
import html
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import zipfile

# Caps. EXTRACT_CAP matches Ai.maxTextAttachmentBytes (256 KiB chars) so text
# that lands in the attachment list never fails a later submit-time size check.
EXTRACT_CAP = 256 * 1024
# A search walks at most this many files per call; files_search has an 8s
# timeout and a pathological root (a node_modules forest) must not blow it.
SCAN_CAP = 50000

TEXT_EXTS = {
    ".txt", ".md", ".rst", ".csv", ".tsv", ".log", ".ini", ".cfg", ".conf",
    ".toml", ".yaml", ".yml", ".json", ".xml", ".qml", ".js", ".ts", ".jsx",
    ".tsx", ".py", ".sh", ".bash", ".zsh", ".fish", ".rb", ".go", ".rs",
    ".c", ".h", ".cpp", ".hpp", ".java", ".kt", ".swift", ".sql", ".css",
    ".diff", ".patch", ".gitignore", ".envrc", ".editorconfig",
}
TEXT_MIMES = {
    "application/json", "application/xml", "application/javascript",
    "application/x-sh", "application/x-shellscript", "application/yaml",
    "application/toml", "application/x-yaml", "application/sql",
    "application/x-python", "application/csv",
}
# Doc formats `extract` can pull text out of without third-party libraries.
DOC_EXTS = {".docx", ".odt", ".epub"}
DOC_MIMES = {
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.oasis.opendocument.text",
    "application/epub+zip",
}

# peek (model-driven reads) refuses these: auth and secrets never reach a
# model through a filename the model chose itself. A person picking the file
# in the dialog is a different decision and is not filtered here.
SENSITIVE_EXTS = {".pem", ".key", ".pfx", ".p12", ".ppk", ".kdbx", ".gpg", ".age"}
SENSITIVE_NAMES = {"credentials", "credentials.json", "secrets", "secrets.json",
                   "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519", "authorized_keys"}


class AttachError(Exception):
    """A failure worth telling the user about; message is shown verbatim."""

    def __init__(self, message, sensitive=False):
        super().__init__(message)
        self.sensitive = sensitive


def canonical_root(path):
    """realpath of a root, or None when it is not currently a directory."""
    try:
        real = os.path.realpath(os.path.expanduser(str(path)))
    except OSError:
        return None
    return real if os.path.isdir(real) else None


def trim_file_protocol(path):
    return str(path)[len("file://"):] if str(path).startswith("file://") else str(path)


def sniff_mime(path):
    """mime from magic bytes, for files whose name carries no extension."""
    try:
        with open(path, "rb") as handle:
            head = handle.read(64)
    except OSError:
        return None
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if head.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if head.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    if head.startswith(b"RIFF") and head[8:12] == b"WEBP":
        return "image/webp"
    if head[4:12] in (b"ftypavif", b"ftypavis"):
        return "image/avif"
    if head.startswith(b"%PDF-"):
        return "application/pdf"
    return None


def classify(name, mime):
    ext = os.path.splitext(name)[1].lower()
    m = mime or ""
    if m.startswith("text/") or m in TEXT_MIMES or ext in TEXT_EXTS:
        return "text"
    if m.startswith("image/"):
        return "image"
    if m.startswith("audio/"):
        return "audio"
    if m.startswith("video/"):
        return "video"
    if m == "application/pdf" or ext == ".pdf":
        return "pdf"
    return "document"


def file_meta(path):
    st = os.stat(path)
    mime = mimetypes.guess_type(path)[0]
    if mime is None:
        # No usable extension: screenshots are saved as `image-<output>` and
        # clipboard images decode to a bare number. Guess from content or the
        # file is misclassified as an unreadable document.
        mime = sniff_mime(path)
    mime = mime or "application/octet-stream"
    name = os.path.basename(path)
    return {
        "path": os.path.realpath(path),
        "name": name,
        "mime": mime,
        "kind": classify(name, mime),
        "bytes": st.st_size,
        "modifiedAt": int(st.st_mtime),
    }


def extractable(meta):
    if meta["kind"] == "text":
        return True
    ext = os.path.splitext(meta["name"])[1].lower()
    if meta["kind"] == "pdf":
        return shutil.which("pdftotext") is not None
    if ext in DOC_EXTS or meta["mime"] in DOC_MIMES:
        return True
    return False


def is_sensitive(name):
    return name.startswith(".") or name.lower() in SENSITIVE_NAMES \
        or os.path.splitext(name)[1].lower() in SENSITIVE_EXTS


# ── Text extraction ────────────────────────────────────────────────────────

_TAG_RE = re.compile(r"<[^>]+>")
_SCRIPT_RE = re.compile(r"<(script|style)\b[^>]*>.*?</\1\s*>", re.IGNORECASE | re.DOTALL)


def _strip_markup(text):
    text = _SCRIPT_RE.sub(" ", text)
    text = re.sub(r"</(p|div|li|h[1-6]|tr|br)\s*>", "\n", text, flags=re.IGNORECASE)
    text = _TAG_RE.sub("", text)
    return html.unescape(text)


def _run(argv, timeout=60):
    try:
        proc = subprocess.run(argv, capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise AttachError(f"{os.path.basename(argv[0])} failed: {e}")
    if proc.returncode != 0:
        detail = proc.stderr.decode("utf-8", "replace").strip().splitlines()
        raise AttachError(detail[-1] if detail else f"{argv[0]} failed")
    return proc.stdout.decode("utf-8", "replace")


def _extract_pdf(path):
    if shutil.which("pdftotext") is None:
        raise AttachError("pdftotext is not installed, so this PDF cannot be read here.")
    return _run(["pdftotext", "-enc", "UTF-8", path, "-"])


def _extract_zip_office(path, member):
    with zipfile.ZipFile(path) as archive:
        if member not in archive.namelist():
            raise AttachError("That document has no readable text body.")
        xml = archive.read(member).decode("utf-8", "replace")
    xml = re.sub(r"</w:p>|</text:p>", "\n", xml)
    return _strip_markup(xml)


def _extract_epub(path):
    with zipfile.ZipFile(path) as archive:
        chapters = sorted(n for n in archive.namelist()
                          if n.lower().endswith((".html", ".xhtml", ".htm")))
        if not chapters:
            raise AttachError("That eBook has no readable chapters.")
        return "\n\n".join(
            _strip_markup(archive.read(n).decode("utf-8", "replace")) for n in chapters)


def extract_text(path, kind, mime, name):
    ext = os.path.splitext(name)[1].lower()
    if kind == "text":
        with open(path, "rb") as handle:
            return handle.read().decode("utf-8", "replace")
    if kind == "pdf":
        return _extract_pdf(path)
    if ext == ".docx":
        return _extract_zip_office(path, "word/document.xml")
    if ext == ".odt":
        return _extract_zip_office(path, "content.xml")
    if ext == ".epub" or mime == "application/epub+zip":
        return _extract_epub(path)
    if kind == "image":
        if shutil.which("tesseract") is None:
            raise AttachError("tesseract is not installed, so this image cannot be read here.")
        return _run(["tesseract", path, "stdout"], timeout=30)
    raise AttachError(f"{kind} files cannot be turned into text here.")


def cleaned_text(path):
    """Extracted text, cut to EXTRACT_CAP; returns (text, truncated)."""
    meta = file_meta(path)
    text = extract_text(path, meta["kind"], meta["mime"], meta["name"])
    text = text.replace("\x00", "").strip()
    if len(text) > EXTRACT_CAP:
        return text[:EXTRACT_CAP], True
    return text, False


# ── Commands ───────────────────────────────────────────────────────────────

def cmd_probe(path):
    meta = file_meta(path)
    meta["extractable"] = extractable(meta)
    return meta


def cmd_extract(path):
    text, truncated = cleaned_text(path)
    if not text:
        raise AttachError("No text could be found in that file.")
    return {"text": text, "characters": len(text), "truncated": truncated}


def _json_fragment(payload):
    """payload as the inside of a JSON string literal: markers in the body
    always sit inside one (the strategies embed them in template strings),
    so what replaces them must not carry unescaped quotes or newlines."""
    return json.dumps(payload, ensure_ascii=False)[1:-1]


def cmd_inject(body_path, spec_json):
    spec = json.loads(spec_json)
    with open(body_path, encoding="utf-8") as handle:
        body = handle.read()
    for item in spec:
        marker, mode, path = item["marker"], item["mode"], trim_file_protocol(item["path"])
        if mode == "b64":
            with open(path, "rb") as handle:
                payload = base64.b64encode(handle.read()).decode("ascii")
        elif mode == "text":
            with open(path, "rb") as handle:
                payload = handle.read().decode("utf-8", "replace")
        elif mode == "extract":
            payload = cleaned_text(path)[0]
        else:
            raise AttachError(f"Unknown attachment mode: {mode}")
        if marker not in body:
            raise AttachError(f"Attachment slot {marker} is missing from the request body.")
        body = body.replace(marker, _json_fragment(payload))
    with open(body_path, "w", encoding="utf-8") as handle:
        handle.write(body)
    return None  # inject replies with nothing on success


def _hidden(path, base):
    return any(part.startswith(".") for part in os.path.relpath(path, base).split(os.sep))


def cmd_search(roots_json, query, limit, kinds_json):
    roots = json.loads(roots_json)
    kinds = set(json.loads(kinds_json))
    needle = query.lower()
    limit = max(1, min(20, limit))
    matches = []
    scanned = 0
    for configured in roots:
        base = canonical_root(configured)
        if base is None:
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            # Hidden trees (.git, .cache, .ssh) are never searched: what the
            # model may see by name should pass the same filter peek applies
            # to what it may see by content.
            dirnames[:] = [d for d in dirnames if not d.startswith(".")]
            for filename in filenames:
                scanned += 1
                if scanned > SCAN_CAP:
                    break
                if needle not in filename.lower() or filename.startswith("."):
                    continue
                path = os.path.join(dirpath, filename)
                if _hidden(path, base):
                    continue
                try:
                    meta = file_meta(path)
                except OSError:
                    continue
                if kinds and meta["kind"] not in kinds:
                    continue
                # Closer filename matches first, then newest.
                matches.append((filename.lower().index(needle), -meta["modifiedAt"], meta))
            if scanned > SCAN_CAP:
                break
        if scanned > SCAN_CAP:
            break
    matches.sort(key=lambda entry: (entry[0], entry[1]))
    return {"query": query, "results": [entry[2] for entry in matches[:limit]]}


def cmd_peek(path, max_chars):
    name = os.path.basename(path)
    if is_sensitive(name):
        # `sensitive: true` makes the QML side report a denial, not an error,
        # and never retryable — a secrets file is refused, not merely broken.
        raise AttachError("That looks like a secrets file, so it was not read.", sensitive=True)
    meta = file_meta(path)
    text = extract_text(path, meta["kind"], meta["mime"], name)
    text = text.replace("\x00", "").strip()
    truncated = len(text) > max_chars
    if truncated:
        text = text[:max_chars]
    if not text:
        raise AttachError("Nothing could be read from that file.")
    return {"name": name, "mime": meta["mime"], "text": text, "truncated": truncated}


def main(argv):
    if len(argv) < 2:
        raise AttachError("No command given.")
    command, args = argv[1], argv[2:]
    if command == "probe" and len(args) == 1:
        return cmd_probe(args[0])
    if command == "extract" and len(args) == 1:
        return cmd_extract(args[0])
    if command == "inject" and len(args) == 2:
        return cmd_inject(args[0], args[1])
    if command == "search" and len(args) == 4:
        return cmd_search(args[0], args[1], int(args[2]), args[3])
    if command == "peek" and len(args) == 2:
        return cmd_peek(args[0], int(args[1]))
    raise AttachError(f"Unknown command: {command}")


if __name__ == "__main__":
    try:
        result = main(sys.argv)
    except AttachError as exc:
        if len(sys.argv) > 1 and sys.argv[1] == "inject":
            print(str(exc))
            sys.exit(1)
        payload = {"error": str(exc)}
        if getattr(exc, "sensitive", False):
            payload["sensitive"] = True
        print(json.dumps(payload, ensure_ascii=False))
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        message = f"Could not read that file: {exc}"
        if len(sys.argv) > 1 and sys.argv[1] == "inject":
            print(message)
            sys.exit(1)
        print(json.dumps({"error": message}, ensure_ascii=False))
    else:
        if result is not None:
            print(json.dumps(result, ensure_ascii=False))
