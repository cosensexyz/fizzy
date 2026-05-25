#!/usr/bin/env bash
# notify-fizzy.sh — Claude Code hook that forwards notifications to Fizzy
# Usage: configure as a Claude Code notification hook.
# The hook reads the agent's JSON from stdin, collects environment context
# (terminal PID, tmux pane, git branch), wraps it in a FizzyNotification
# envelope, and POSTs to Fizzy's HTTP server.

[[ "$OSTYPE" == darwin* ]] || exit 0
command -v jq curl >/dev/null 2>&1 || exit 0

payload=$(cat)
printf '%s' "$payload" | jq empty 2>/dev/null || exit 0

# --- Collect environment context ---
env_json='{}'

# Terminal PID: walk process tree from PPID, match known terminals
_find_terminal_pid() {
    local p="$1" h=0
    while [ "$p" -gt 1 ] 2>/dev/null && [ "$h" -lt 20 ]; do
        local name
        name=$(ps -o comm= -p "$p" 2>/dev/null | xargs basename 2>/dev/null || true)
        case "$name" in
            ghostty|iTerm2|Terminal) echo "$p"; return ;;
        esac
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        h=$((h + 1))
    done
}

terminal_pid=$(_find_terminal_pid "$PPID")

# Inside tmux: also check tmux client PIDs
if [ -z "$terminal_pid" ] && [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
    for cpid in $(tmux list-clients -F '#{client_pid}' 2>/dev/null); do
        terminal_pid=$(_find_terminal_pid "$cpid")
        [ -n "$terminal_pid" ] && break
    done
fi

[ -n "$terminal_pid" ] && \
    env_json=$(printf '%s' "$env_json" | jq --argjson pid "$terminal_pid" '. + {terminal_pid: $pid}')

# tmux context
if [ -n "${TMUX_PANE:-}" ] && [ -n "${TMUX:-}" ]; then
    socket_path=$(echo "$TMUX" | cut -d, -f1)
    session_name=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)
    client_tty=$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)
    env_json=$(printf '%s' "$env_json" | jq \
        --arg pane "$TMUX_PANE" --arg socket "$socket_path" \
        '. + {tmux_pane: $pane, tmux_socket_path: $socket}')
    [ -n "$session_name" ] && \
        env_json=$(printf '%s' "$env_json" | jq --arg s "$session_name" '. + {tmux_session_name: $s}')
    [ -n "$client_tty" ] && \
        env_json=$(printf '%s' "$env_json" | jq --arg t "$client_tty" '. + {tmux_client_tty: $t}')
fi

# git branch
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty')
if [ -n "$cwd" ]; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)
    [ -n "$branch" ] && \
        env_json=$(printf '%s' "$env_json" | jq --arg b "$branch" '. + {git_branch: $b}')
fi

# --- Assemble envelope and POST ---
envelope=$(jq -n \
    --arg agent "claude_code" \
    --argjson payload "$payload" \
    --argjson env "$env_json" \
    '{agent: $agent, payload: $payload, env: $env}')

curl -s -X POST http://127.0.0.1:7319/notification \
    -H "Content-Type: application/json" \
    -d "$envelope" >/dev/null 2>&1 &
disown
