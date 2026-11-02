#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
if [ ! -d "$HOME/Applications/MacSwitch.app" ]; then
    /bin/bash "$PROJECT_ROOT/Scripts/install.sh"
else
    open "$HOME/Applications/MacSwitch.app"
fi
