#!/bin/zsh
# Shows the saved settings, whether an update is ready and, while a game runs, which translator
# it's actually using.
set -euo pipefail
source "${0:A:h}/config.sh"

if [[ ! -x "$LAUNCHER" ]]; then
  if [[ -x $LEGACY_APP/Contents/MacOS/wineskinlauncher ]]; then
    echo "Found a DXMetal install: run ${0:h}/setup.sh to move it to Vapor, keeping Steam and your games."
  else
    echo "Not installed yet; run ${0:h}/setup.sh first."
  fi
  exit 0
fi

echo "Settings: $(describe_settings)"
needs_update && echo "Update ready: run ${0:h}/setup.sh. Steam, your games and settings stay."
pgrep -x wineserver >/dev/null && echo "Steam/Wine: running" || echo "Steam/Wine: not running"
running_games | sed 's/^/Running: /'
