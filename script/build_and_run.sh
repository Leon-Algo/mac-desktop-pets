#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DesktopPets"
BUNDLE_ID="com.codex.DesktopPets"
APP_BUNDLE="$PROJECT_DIR/build/DesktopPets.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/DesktopPets"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
"$PROJECT_DIR/Scripts/package-app.sh" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

open_app_for_verification() {
  /usr/bin/open -n \
    --env DESKTOP_PETS_SUPPRESS_CONTROL_HINT=1 \
    --env DESKTOP_PETS_FORCE_VISIBLE=1 \
    "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app_for_verification
    REPORT=""
    for _ in {1..20}; do
      sleep 0.5
      RUNNING_PID="$(pgrep -x "$APP_NAME" | head -n 1 || true)"
      if [ -n "$RUNNING_PID" ]; then
        REPORT="$($APP_BINARY --inspect-running "$RUNNING_PID")"
        if echo "$REPORT" | grep -q '"status":"ok"'; then
          break
        fi
      fi
    done
    echo "$REPORT"
    echo "$REPORT" | grep -q '"status":"ok"'
    pkill -x "$APP_NAME"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
