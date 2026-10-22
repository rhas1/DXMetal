#!/bin/zsh
# Shows the saved settings and, while a game runs, which renderer it's actually using.
set -euo pipefail
source "${0:A:h}/config.sh"

[[ -x "$LAUNCHER" ]] || { echo "Not installed yet; run ${0:h}/setup.sh first."; exit 0; }

echo "Settings: $(describe_settings)"
pgrep -x wineserver >/dev/null && echo "Steam/Wine: running" || echo "Steam/Wine: not running"
running_games | sed 's/^/Running: /'
