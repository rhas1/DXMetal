#!/bin/zsh
# Closes Steam and everything else running in Wine. Asks Steam to exit cleanly first
# (so it saves its state and cloud saves), then force-quits whatever is left, straight away if
# Steam isn't responding.
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
  log="$STEAM_DIR/logs/webhelper.txt"
  seen=$(wc -l < "$log" 2>/dev/null || echo 0)
  wine_exec 'C:\Program Files (x86)\Steam\steam.exe' -shutdown >/dev/null 2>&1 &
  # Steam starts closing within a second or two, and its window logs that here. If it hasn't after
  # 10 seconds, it's stuck (as after its in-game overlay opens) and won't get any further.
  if ! wait_for_wine 10; then
    if tail -n +$(( seen + 1 )) "$log" 2>/dev/null | grep -qE "'Shutdown'|Quit message loop"; then
      wait_for_wine 50 || true
    else
      echo "Steam isn't responding."
    fi
  fi
fi

if pgrep -x wineserver >/dev/null; then
  echo "Force-quitting what's left..."
  [[ -x "$LAUNCHER" ]] && "$LAUNCHER" WSS-wineserverkill >/dev/null 2>&1 || true
  pkill -x wineserver || true
  wait_for_wine 10 || true
fi

pgrep -x wineserver >/dev/null && { echo "Wine is still running."; exit 1; }
echo "All Wine sessions closed."
