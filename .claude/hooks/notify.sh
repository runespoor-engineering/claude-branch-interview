#!/usr/bin/env bash
# Claude Code sound + visual notifications (macOS).
# Usage: notify.sh <event>   where event is notification | stop | subagent
# Wired via .claude/settings.json hooks (Notification / Stop / SubagentStop).
# Reads the hook JSON payload from stdin. Never blocks or fails the session.

event="${1:-stop}"
input="$(cat 2>/dev/null)"

title="Claude Code"

case "$event" in
  notification)
    sound="/System/Library/Sounds/Funk.aiff"
    msg="$(printf '%s' "$input" | /usr/bin/python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("message","") or "")
except Exception: pass' 2>/dev/null)"
    [ -z "$msg" ] && msg="Waiting for your input"
    ;;
  stop)
    sound="/System/Library/Sounds/Glass.aiff"
    msg="Task complete"
    ;;
  subagent)
    sound="/System/Library/Sounds/Pop.aiff"
    msg="Subagent finished"
    ;;
  *)
    sound="/System/Library/Sounds/Glass.aiff"
    msg="$event"
    ;;
esac

# Project name for banner subtitle.
subtitle="$(basename "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null)"

# Strip characters that would break the AppleScript string literal.
sanitize() { printf '%s' "$1" | tr -d '"\\' | tr '\n' ' '; }
msg="$(sanitize "$msg")"
subtitle="$(sanitize "$subtitle")"

# Sound (non-blocking).
[ -f "$sound" ] && afplay "$sound" >/dev/null 2>&1 &

# Visual banner (built-in macOS, no dependencies).
osascript -e "display notification \"$msg\" with title \"$title\" subtitle \"$subtitle\"" >/dev/null 2>&1

exit 0
