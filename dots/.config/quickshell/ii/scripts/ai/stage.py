#!/usr/bin/env python3

"""
AI Session Stage Script
Stages an AI session for later commit. Creates a staged copy.
"""

import json
import os
import argparse
from pathlib import Path

# Session storage directory
SESSIONS_DIR = "/home/webcubed/.local/state/quickshell/user/ai/sessions"

def ensure_dir(path: str):
    Path(path).mkdir(parents=True, exist_ok=True)

def stage_session(session_id: str, session_file: str):
    """Stage a session."""
    try:
        with open(session_file, "r") as f:
            session = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error loading session file: {e}", file=sys.stderr)
        return ""
    
    ensure_dir(SESSIONS_DIR)
    staged_dir = os.path.join(SESSIONS_DIR, "staged")
    ensure_dir(staged_dir)
    
    session_path = os.path.join(staged_dir, f"{session_id}.json")
    
    with open(session_path, "w") as f:
        json.dump(session, f, indent=2, default=str)
    
    return f"stage-{session_id}-{os.path.getmtime(session_file)}"

def main():
    parser = argparse.ArgumentParser(description="AI Session Stage Script")
    parser.add_argument("dir", help="Sessions directory")
    parser.add_argument("session_id", help="Session ID")
    parser.add_argument("operation_id", help="Operation ID")
    
    args = parser.parse_args()
    
    # Find session file in main directory
    session_file = os.path.join(args.dir, f"{args.session_id}.json")
    
    result = stage_session(args.session_id, session_file)
    if result:
        print(result)
    else:
        sys.exit(1)

if __name__ == "__main__":
    import sys
    main()
