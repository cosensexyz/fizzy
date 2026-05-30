#!/usr/bin/env bash
set -euo pipefail

FIZZY_PORT=7319
FIZZY_PID=""
PASS=0
FAIL=0

cleanup() {
    [ -n "$FIZZY_PID" ] && kill "$FIZZY_PID" 2>/dev/null && wait "$FIZZY_PID" 2>/dev/null
}
trap cleanup EXIT

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        printf '  ✓ %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  ✗ %s (expected=%s actual=%s)\n' "$label" "$expected" "$actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_neq() {
    local label="$1" rejected="$2" actual="$3"
    if [ "$rejected" != "$actual" ]; then
        printf '  ✓ %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  ✗ %s (got rejected value=%s)\n' "$label" "$rejected"
        FAIL=$((FAIL + 1))
    fi
}

# --- Build ---
printf 'Building Fizzy...\n'
swift build --quiet 2>&1

# --- Launch ---
printf 'Launching Fizzy...\n'
swift run Fizzy &>/dev/null &
FIZZY_PID=$!

# --- Wait for server ---
printf 'Waiting for server...\n'
for i in $(seq 1 100); do
    if curl -s -o /dev/null http://127.0.0.1:$FIZZY_PORT/notification 2>/dev/null; then
        break
    fi
    [ "$i" -eq 100 ] && { printf 'Server did not start\n'; exit 1; }
    sleep 0.1
done

notification_json() {
    local cwd="$1" msg="$2" sid="$3"
    cat <<ENDJSON
{
    "agent": "claude_code",
    "payload": {
        "session_id": "$sid", "transcript_path": "/tmp/t", "cwd": "$cwd",
        "hook_event_name": "Notification", "message": "$msg",
        "notification_type": "idle_prompt"
    },
    "env": {}
}
ENDJSON
}

# --- Test 1: Notification receipt ---
printf '\nTest: notification receipt\n'
status=$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST http://127.0.0.1:$FIZZY_PORT/notification \
    -H 'Content-Type: application/json' \
    -d "$(notification_json /tmp/projA "hello" s1)")
assert_eq "POST /notification returns 200" "200" "$status"

# --- Test 2: Multi-notification stability ---
printf '\nTest: multi-notification stability\n'
curl -s -o /dev/null -X POST http://127.0.0.1:$FIZZY_PORT/notification \
    -H 'Content-Type: application/json' \
    -d "$(notification_json /tmp/projB "world" s2)"
sleep 0.5
kill -0 "$FIZZY_PID" 2>/dev/null
assert_eq "Fizzy still alive after 2 notifications" "0" "$?"

# --- Test 3: No focus steal ---
printf '\nTest: no focus steal\n'
frontmost=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
assert_neq "frontmost app is not Fizzy" "Fizzy" "$frontmost"

# --- Summary ---
printf '\n--- Results: %d passed, %d failed ---\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
