#!/usr/bin/env bash
# session-end-fizzy.sh — Claude Code hook that tells Fizzy a session ended
# Usage: configure as a Claude Code SessionEnd hook.
# Reads session_id from stdin, POSTs to Fizzy's /session-end endpoint.

[[ "$OSTYPE" == darwin* ]] || exit 0
command -v jq curl >/dev/null 2>&1 || exit 0

payload=$(cat)
session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty')
[ -n "$session_id" ] || exit 0

body=$(jq -n --arg agent "claude_code" --arg sid "$session_id" \
    '{agent: $agent, session_id: $sid}')

curl -s -X POST http://127.0.0.1:7319/session-end \
    -H "Content-Type: application/json" \
    -d "$body" >/dev/null 2>&1 &
disown
