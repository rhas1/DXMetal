#!/bin/zsh
# Closes Steam and everything else running in Wine. Asks Steam to exit cleanly first
# (so it saves its state and cloud saves), then force-quits whatever is left.
set -euo pipefail
source "${0:A:h}/config.sh"

pgrep -x wineserver >/dev/null || { echo "Nothing running."; exit 0; }

games=$(running_games)
if [[ -n $games ]]; then
  echo "Game still running: ${games% on *}"
  read "?Unsaved progress will be lost. Close anyway? [y/N] " ans || ans=n
  [[ $ans == [yY] ]] || exit 0
fi

if pgrep -f 'steam\.exe' >/dev/null; then
  echo "Asking Steam to exit..."
  wine_exec 'C:\Program Files (x86)\Steam\steam.exe' -shutdown >/dev/null 2>&1 &
  wait_for_wine 60 || true
fi

if pgrep -x wineserver >/dev/null; then
  echo "Force-quitting what's left..."
  [[ -x "$LAUNCHER" ]] && "$LAUNCHER" WSS-wineserverkill >/dev/null 2>&1 || true
  pkill -x wineserver || true
  wait_for_wine 10 || true
fi

pgrep -x wineserver >/dev/null && { echo "Wine is still running."; exit 1; }
echo "All Wine sessions closed."
