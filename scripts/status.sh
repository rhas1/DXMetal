#!/bin/zsh
# Shows the saved settings, whether an update is ready and, while a game runs, which translator
# it's actually using.
set -euo pipefail
source "${0:A:h}/config.sh"

if [[ ! -x "$LAUNCHER" ]]; then
  echo "Not installed yet; run ${0:h}/setup.sh first."
  exit 0
fi

[[ $APP == $INSTALL_PATH ]] ||
  echo "Vapor Steam is in ${APP:h}, where Spotlight lists it: run ${0:h}/setup.sh to move it. Steam, your games and settings stay."
echo "Settings: $(describe_settings)"
needs_update && echo "Update ready: run ${0:h}/setup.sh. Steam, your games and settings stay."
pgrep -x wineserver >/dev/null && echo "Steam/Wine: running" || echo "Steam/Wine: not running"
running_games | sed 's/^/Running: /'
