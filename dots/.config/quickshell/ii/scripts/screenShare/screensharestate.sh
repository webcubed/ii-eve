#!/bin/bash
# Publishes the apps currently screen-sharing (PipeWire Stream/Input/Video or
# media.role=Screen nodes) to the state file the bar indicator reads.
#
# This used to leak: every shell restart left another `while true` loop behind,
# and each copy ran `pw-dump | jq` (parsing the whole PipeWire graph) every 1.5s.
# A machine with a few hours of restarts had ~25 of them, which cost about a full
# CPU core between them. Now the watcher takes over the previous instance, exits
# when the shell that started it is gone, and polls far less often.

STATE_FILE="$HOME/.local/state/quickshell/user/generated/screenshare/apps.txt"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/quickshell-screenshare-watch.pid"
POLL_INTERVAL=5
mkdir -p "$(dirname "$STATE_FILE")"

SHELL_PID=$PPID

# Single instance: kill the watcher a previous shell session left behind.
if [ -f "$PID_FILE" ]; then
    previous=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$previous" ] && [ "$previous" != "$$" ] && kill -0 "$previous" 2>/dev/null; then
        kill "$previous" 2>/dev/null
    fi
fi
printf '%s\n' "$$" > "$PID_FILE"

cleanup() {
    if [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then
        rm -f "$PID_FILE"
    fi
}
trap cleanup EXIT

apps_running() {
    pw-dump 2>/dev/null | jq -r '.[] | select((.info.props["media.class"] == "Stream/Input/Video" or .info.props["media.role"] == "Screen") and .info.state == "running") | .info.props["node.name"]' | paste -sd ", " -
}

LAST_STATE=""
publish() {
    local apps current
    apps=$(apps_running)
    current="${apps:-NONE}"
    [ "$current" = "$LAST_STATE" ] && return
    LAST_STATE="$current"
    printf '%s\n' "$current" > "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

publish

while true; do
    # Orphaned watchers used to pile up one per shell restart; stop as soon as the
    # shell that spawned us is gone instead of polling for the rest of the session.
    if ! kill -0 "$SHELL_PID" 2>/dev/null; then
        printf 'NONE\n' > "$STATE_FILE"
        exit 0
    fi
    sleep "$POLL_INTERVAL"
    publish
done
