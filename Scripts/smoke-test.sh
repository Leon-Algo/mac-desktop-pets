#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$PROJECT_DIR/script/build_and_run.sh" --verify
"$PROJECT_DIR/build/DesktopPets.app/Contents/MacOS/DesktopPets" --interaction-self-test
