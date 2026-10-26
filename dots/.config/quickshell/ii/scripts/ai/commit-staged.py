#!/usr/bin/env python3

"""
AI Session Commit-Staged Script
Commits a staged session to the main storage location.
"""

import json
import os
import sys
import argparse
from pathlib import Path

# Session storage directory
SESSIONS_DIR = "/home/webcubed/.local/state/quickshell/user/ai/sessions"

def ensure_dir(path: str):
    Path(path).mkdir(parents=True, exist_ok=True)

def commit_staged_session(session_id: str, staging_op_id: str):
    """Commit a staged session to main storage."""
    try:
        staged_dir = os.path.join(SESSIONS_DIR, "staged")
        staged_path = os.path.join(staged_dir, f"{session_id}.json")
        
        if not os.path.exists(staged_path):
            return ""
        
        # Load staged session
        with open(staged_path, "r") as f:
            session = json.load(f)
        
        # Save to main location
        session_path = os.path.join(SESSIONS_DIR, f"{session_id}.json")
        ensure_dir(os.path.dirname(session_path))
        
        with open(session_path, "w") as f:
            json.dump(session, f, indent=2, default=str)
        
        # Clean up staged file
        os.remove(staged_path)
        
        return f"commit-{session_id}-{os.path.getmtime(staged_path)}"
    
    except Exception as e:
        print(f"Error committing staged session: {e}", file=sys.stderr)
        return ""

def main():
    parser = argparse.ArgumentParser(description="AI Session Commit-Staged Script")
    parser.add_argument("dir", help="Sessions directory")
    parser.add_argument("session_id", help="Session ID")
    parser.add_argument("staging_op_id", help="Staging operation ID")
    
    args = parser.parse_args()
    
    result = commit_staged_session(args.session_id, args.staging_op_id)
    if result:
        print(result)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()