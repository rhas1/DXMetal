#!/bin/zsh
# Deletes DXMetal.app, including Steam, installed games and saved sign-ins.
# Run setup.sh afterwards to install again.
set -euo pipefail
source "${0:A:h}/config.sh"

# Only ever delete something that is actually a DXMetal app.
[[ -x "$LAUNCHER" ]] || { echo "Nothing to remove: no DXMetal app at $APP."; exit 0; }
pgrep -x wineserver >/dev/null && { echo "Quit Steam first (${0:h}/close-wine.sh)."; exit 1; }

read "?Delete $APP, including Steam and all installed games? [y/N] " ans || ans=n
[[ $ans == [yY] ]] || exit 0
rm -rf "$APP"
echo "Removed. Run ${0:h}/setup.sh to install again."
