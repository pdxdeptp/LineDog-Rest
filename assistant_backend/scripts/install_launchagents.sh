#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/MalDaze"
VENV_DIR="$BACKEND_DIR/.venv"

echo "=== MalDaze Learning Assistant Setup ==="

# --- Detect Python venv / uv ---
if [ -f "$VENV_DIR/bin/uvicorn" ]; then
    UVICORN_PATH="$VENV_DIR/bin/uvicorn"
elif command -v uvicorn &>/dev/null; then
    UVICORN_PATH="$(command -v uvicorn)"
else
    echo "Error: uvicorn not found. Run 'pip install -e .' inside assistant_backend/ first."
    exit 1
fi

# --- Prompt for config if .env missing ---
ENV_FILE="$BACKEND_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    read -rp "Enter GEMINI_API_KEY: " GEMINI_API_KEY
    DB_PATH="$HOME/Library/Application Support/MalDaze/learning.db"
    PLAN_MD_PATH="$HOME/Library/Application Support/MalDaze/plan.md"
    echo "GEMINI_API_KEY=$GEMINI_API_KEY" > "$ENV_FILE"
    echo "DB_PATH=$DB_PATH" >> "$ENV_FILE"
    echo "PLAN_MD_PATH=$PLAN_MD_PATH" >> "$ENV_FILE"
    echo "PORT=8765" >> "$ENV_FILE"
    echo "Created $ENV_FILE"
fi

source "$ENV_FILE"
DB_PATH="${DB_PATH:-$HOME/Library/Application Support/MalDaze/learning.db}"
PLAN_MD_PATH="${PLAN_MD_PATH:-$HOME/Library/Application Support/MalDaze/plan.md}"

# --- Create directories ---
mkdir -p "$LOG_DIR"
mkdir -p "$(dirname "$DB_PATH")"
touch "$PLAN_MD_PATH" 2>/dev/null || true

# --- Install backend KeepAlive LaunchAgent ---
BACKEND_PLIST="$LAUNCH_AGENTS_DIR/com.maldaze.backend.plist"
sed \
    -e "s|UVICORN_PATH_PLACEHOLDER|$UVICORN_PATH|g" \
    -e "s|BACKEND_DIR_PLACEHOLDER|$BACKEND_DIR|g" \
    -e "s|GEMINI_API_KEY_PLACEHOLDER|$GEMINI_API_KEY|g" \
    -e "s|DB_PATH_PLACEHOLDER|$DB_PATH|g" \
    -e "s|PLAN_MD_PATH_PLACEHOLDER|$PLAN_MD_PATH|g" \
    -e "s|LOG_DIR_PLACEHOLDER|$LOG_DIR|g" \
    "$SCRIPT_DIR/com.maldaze.backend.plist" > "$BACKEND_PLIST"

# --- Install morning agent trigger LaunchAgent ---
MORNING_PLIST="$LAUNCH_AGENTS_DIR/com.maldaze.morning-agent.plist"
sed \
    -e "s|LOG_DIR_PLACEHOLDER|$LOG_DIR|g" \
    "$SCRIPT_DIR/com.maldaze.morning-agent.plist" > "$MORNING_PLIST"

# --- Load both LaunchAgents ---
launchctl unload "$BACKEND_PLIST" 2>/dev/null || true
launchctl load "$BACKEND_PLIST"
echo "✓ Backend LaunchAgent loaded (KeepAlive)"

launchctl unload "$MORNING_PLIST" 2>/dev/null || true
launchctl load "$MORNING_PLIST"
echo "✓ Morning Agent LaunchAgent loaded (daily trigger)"

echo ""
echo "Setup complete! Backend will start automatically on login."
echo "Logs: $LOG_DIR"
