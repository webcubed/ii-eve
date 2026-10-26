#!/usr/bin/env python3

"""
AI Sessions Management Script
Manages AI chat sessions and persistent state for the Quickshell II AI service.

This script provides basic file-based session persistence for AI conversations,
supporting stage/save/commit/abort operations needed by the durable submission
pipeline.
"""

import json
import os
import sys
import argparse
from pathlib import Path
from datetime import datetime

# Session storage directory
SESSIONS_DIR = "/home/webcubed/.local/state/quickshell/user/ai/sessions"

def ensure_dir(path: str):
    Path(path).mkdir(parents=True, exist_ok=True)

def load_session(session_id: str) -> dict:
    """Load a session from disk."""
    session_path = os.path.join(SESSIONS_DIR, f"{session_id}.json")
    try:
        with open(session_path, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None

def save_session(session_id: str, session: dict) -> str:
    """Save a session to disk."""
    ensure_dir(SESSIONS_DIR)
    session_path = os.path.join(SESSIONS_DIR, f"{session_id}.json")
    
    with open(session_path, "w") as f:
        json.dump(session, f, indent=2, default=str)
    
    return f"save-{session_id}-{datetime.now().timestamp()}"

def stage_session(session_id: str, session: dict) -> str:
    """Stage a session for later commit."""
    ensure_dir(SESSIONS_DIR)
    staged_dir = os.path.join(SESSIONS_DIR, "staged")
    ensure_dir(staged_dir)
    
    session_path = os.path.join(staged_dir, f"{session_id}.json")
    
    with open(session_path, "w") as f:
        json.dump(session, f, indent=2, default=str)
    
    return f"stage-{session_id}-{datetime.now().timestamp()}"

def commit_staged_session(session_id: str, staging_op_id: str) -> str:
    """Commit a staged session to the main storage."""
    staged_dir = os.path.join(SESSIONS_DIR, "staged")
    staged_path = os.path.join(staged_dir, f"{session_id}.json")
    
    if not os.path.exists(staged_path):
        return ""
    
    with open(staged_path, "r") as f:
        session = json.load(f)
    
    # Save to main location
    session_path = os.path.join(SESSIONS_DIR, f"{session_id}.json")
    with open(session_path, "w") as f:
        json.dump(session, f, indent=2, default=str)
    
    # Clean up staged file
    os.remove(staged_path)
    
    return f"commit-{session_id}-{datetime.now().timestamp()}"

def abort_staged_session(session_id: str, staging_op_id: str) -> str:
    """Abort a staged session, discarding it."""
    staged_dir = os.path.join(SESSIONS_DIR, "staged")
    staged_path = os.path.join(staged_dir, f"{session_id}.json")
    
    if os.path.exists(staged_path):
        os.remove(staged_path)
    
    return f"abort-{session_id}-{datetime.now().timestamp()}"

def list_sessions():
    """List all available sessions."""
    ensure_dir(SESSIONS_DIR)
    
    sessions = []
    for file in os.listdir(SESSIONS_DIR):
        if file.endswith(".json") and not file.startswith("."):
            session_path = os.path.join(SESSIONS_DIR, file)
            try:
                with open(session_path, "r") as f:
                    session = json.load(f)
                    sessions.append({
                        "id": session.get("id", file[:-5]),
                        "title": session.get("title", "Untitled"),
                        "createdAt": session.get("createdAt"),
                        "updatedAt": session.get("updatedAt", session.get("createdAt"))
                    })
            except (json.JSONDecodeError, FileNotFoundError):
                pass
    
    return sessions

def main():
    parser = argparse.ArgumentParser(description="AI Sessions Management Script")
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")
    
    # save command
    parser_save = subparsers.add_parser("save", help="Save a session")
    parser_save.add_argument("session_id", help="Session ID")
    parser_save.add_argument("session_file", help="Path to session file to load")
    
    # stage command  
    parser_stage = subparsers.add_parser("stage", help="Stage a session")
    parser_stage.add_argument("session_id", help="Session ID")
    parser_stage.add_argument("session_file", help="Path to session file to load")
    
    # commit-staged command
    parser_commit = subparsers.add_parser("commit-staged", help="Commit a staged session")
    parser_commit.add_argument("dir", help="Sessions directory")
    parser_commit.add_argument("session_id", help="Session ID")
    parser_commit.add_argument("staging_op_id", help="Staging operation ID")
    
    # abort-staged command
    parser_abort = subparsers.add_parser("abort-staged", help="Abort a staged session")
    parser_abort.add_argument("dir", help="Sessions directory")
    parser_abort.add_argument("session_id", help="Session ID")
    parser_abort.add_argument("staging_op_id", help="Staging operation ID")
    
    args = parser.parse_args()
    
    if args.command == "save":
        with open(args.session_file, "r") as f:
            session = json.load(f)
        result = save_session(args.session_id, session)
        print(result)
    
    elif args.command == "stage":
        with open(args.session_file, "r") as f:
            session = json.load(f)
        result = stage_session(args.session_id, session)
        print(result)
    
    elif args.command == "commit-staged":
        result = commit_staged_session(args.session_id, args.staging_op_id)
        print(result)
    
    elif args.command == "abort-staged":
        result = abort_staged_session(args.session_id, args.staging_op_id)
        print(result)
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
