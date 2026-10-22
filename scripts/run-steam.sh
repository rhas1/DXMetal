#!/bin/zsh
# Starts Windows Steam, optionally changing settings first.
# Usage: ./run-steam.sh [RETINA DXMT HUD]   (no arguments keeps the current settings)
#   RETINA  0 = scaled resolution (faster), 1 = full Retina resolution
#   DXMT    0 = D3DMetal, 1 = DXMT
#   HUD     0 = off, 1 = Metal performance overlay (FPS) in games
# e.g. ./run-steam.sh 0 1 1
set -euo pipefail
source "${0:A:h}/config.sh"

[[ -f "$STEAM_DIR/steam.exe" ]] || { echo "Steam isn't installed yet; run ${0:h}/setup.sh first."; exit 1; }

if (( $# )); then
  [[ $# == 3 && $1 == [01] && $2 == [01] && $3 == [01] ]] ||
    { echo "Usage: $0 [RETINA DXMT HUD], each 0 or 1 (e.g. $0 0 1 1)"; exit 1; }
  if [[ "$1 $2 $3" != "$(get_retina) $(get_dxmt) $(get_hud)" ]]; then
    # All three settings are only read when Steam/Wine starts.
    pgrep -x wineserver >/dev/null &&
      { echo "Steam is running with $(describe_settings). Quit it first (${0:h}/close-wine.sh)."; exit 1; }
    if [[ $1 != $(get_retina) ]]; then
      set_retina $1
      echo "Resolution mode changed: pick the resolution again in the game's display settings."
    fi
    set_dxmt $2
    set_hud $3
  fi
fi

echo "Steam: $(describe_settings)"
# Detached, so closing this Terminal window doesn't take Steam with it.
nohup "$LAUNCHER" >/dev/null 2>&1 &!
