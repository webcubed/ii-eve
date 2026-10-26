#!/usr/bin/env python3
import os
import re
import sys

if len(sys.argv) < 3:
    sys.exit(1)

tag = sys.argv[1].upper()
code = sys.argv[2]
filepath = os.path.expanduser("~/.config/hypr/custom/general.lua")

os.makedirs(os.path.dirname(filepath), exist_ok=True)
content = ""
if os.path.exists(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

pattern = rf"-- {tag}_START.*?\n-- {tag}_END\n?"
replacement = f"-- {tag}_START\n{code}\n-- {tag}_END\n"

if f"-- {tag}_START" in content:
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
else:
    if content and not content.endswith("\n"):
        content += "\n"
    content += replacement

with open(filepath, "w", encoding="utf-8") as f:
    f.write(content)
