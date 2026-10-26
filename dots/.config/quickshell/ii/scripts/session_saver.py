#!/usr/bin/env python3
import json
import os
import subprocess

IGNORE_CLASSES = {"org.quickshell", "quickshell", "qs", "hyprland", "Happ", "settings.qml"}
RESTORE_FILE = os.path.expanduser("~/.config/hypr/custom/session_restore.sh")

try:
    raw = subprocess.check_output(["hyprctl", "clients", "-j"]).decode("utf-8")
    clients = json.loads(raw)
except Exception:
    clients = []

commands = []
for c in clients:
    cls = c.get("initialClass") or c.get("class") or ""
    if not cls or cls in IGNORE_CLASSES:
        continue
    ws = c.get("workspace", {}).get("id")
    pid = c.get("pid")
    exe_name = cls

    if pid and os.path.exists(f"/proc/{pid}/exe"):
        try:
            exe_path = os.readlink(f"/proc/{pid}/exe")
            bname = os.path.basename(exe_path)
            if bname and bname not in IGNORE_CLASSES:
                exe_name = bname
        except Exception:
            pass

    if exe_name == "telegram-desktop" or cls == "org.telegram.desktop":
        exe_name = "telegram-desktop"
    elif exe_name == "dolphin" or cls == "org.kde.dolphin":
        exe_name = "dolphin"

    if ws and exe_name:
        commands.append(f"hyprctl dispatch exec '[workspace {ws} silent] {exe_name}'")

if commands:
    with open(RESTORE_FILE, "w") as f:
        f.write("#!/bin/bash\nsleep 2\n")
        for cmd in commands:
            f.write(cmd + "\n")
    os.chmod(RESTORE_FILE, 0o755)
