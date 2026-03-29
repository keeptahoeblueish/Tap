#!/bin/bash
# tap-hook — Claude Code hook for Tap notifications
# Auto-installed by Tap.app. Do not edit manually.
# If running standalone, set SOCKET_PATH to your Tap socket location.

SOCKET_PATH="${TAP_SOCKET_PATH:-$HOME/Library/Application Support/Tap/tap.sock}"
EVENT_TYPE="${TAP_EVENT_TYPE:-notification}"

if [ ! -S "$SOCKET_PATH" ]; then
    [ "$EVENT_TYPE" = "permission" ] && echo '{"decision": "ask"}'
    exit 0
fi

INPUT=$(cat)
EVENT_ID="evt_$(date +%s)_$$"

case "$EVENT_TYPE" in
    permission)
        TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")
        TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); i=d.get('tool_input',{}); print(i if isinstance(i,str) else json.dumps(i)[:100])" 2>/dev/null || echo "")
        MESSAGE="Claude wants to run: ${TOOL_NAME}${TOOL_INPUT:+ ($TOOL_INPUT)}"
        RESPONSE=$(echo "{\"type\":\"permission\",\"id\":\"$EVENT_ID\",\"tool_name\":\"$TOOL_NAME\",\"tool_input\":\"$TOOL_INPUT\",\"message\":\"$MESSAGE\",\"timestamp\":$(date +%s)}" | socat - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null)
        [ -z "$RESPONSE" ] && echo '{"decision": "ask"}' || echo "$RESPONSE"
        ;;
    complete)
        echo "{\"type\":\"complete\",\"id\":\"$EVENT_ID\",\"message\":\"Task complete\",\"timestamp\":$(date +%s)}" | socat - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null &
        ;;
    error)
        ERROR_MSG=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_result','Error occurred')[:200])" 2>/dev/null || echo "An error occurred")
        echo "{\"type\":\"error\",\"id\":\"$EVENT_ID\",\"message\":\"$ERROR_MSG\",\"timestamp\":$(date +%s)}" | socat - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null &
        ;;
    blocker)
        echo "{\"type\":\"blocker\",\"id\":\"$EVENT_ID\",\"message\":\"Claude needs manual action from you\",\"timestamp\":$(date +%s)}" | socat - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null &
        ;;
esac
exit 0
