#!/bin/zsh
# Starts Windows Steam, optionally changing settings first.
# Usage: ./run-steam.sh [RETINA [DXMT [HUD [METALFX]]]]   (settings you leave off stay as they are)
#   RETINA   0 = scaled resolution (faster), 1 = full Retina resolution
#   DXMT     0 = D3DMetal, 1 = DXMT
#   HUD      0 = off, 1 = Metal performance overlay (FPS) in games
#   METALFX  0 = off, 1 = MetalFX upscales each frame 2x (DXMT at scaled resolution only)
# e.g. ./run-steam.sh 0 1 0 1
set -euo pipefail
source "${0:A:h}/config.sh"

[[ -f "$STEAM_DIR/steam.exe" ]] || { echo "Steam isn't installed yet; run ${0:h}/setup.sh first."; exit 1; }

self=$0  # inside functions, $0 is the function's name
usage() { echo "Usage: $self [RETINA [DXMT [HUD [METALFX]]]], each 0 or 1 (e.g. $self 0 1 0 1)"; exit 1; }
(( $# <= 4 )) || usage
for a in "$@"; do [[ $a == [01] ]] || usage; done

current=($(get_retina) $(get_dxmt) $(get_hud) $(get_metalfx))
wanted=("$@" "${(@)current[$#+1,-1]}")
if [[ "$wanted" != "$current" ]]; then
  # All settings are only read when Steam/Wine starts.
  pgrep -x wineserver >/dev/null &&
    { echo "Steam is running with $(describe_settings). Quit it first (${0:h}/close-wine.sh)."; exit 1; }
  if [[ $wanted[1] != $current[1] ]]; then
    set_retina $wanted[1]
    echo "Resolution mode changed: pick the resolution again in the game's display settings."
  fi
  set_dxmt $wanted[2]
  set_hud $wanted[3]
  set_metalfx $wanted[4]
fi

echo "Steam: $(describe_settings)"
metalfx_active && export DXMT_METALFX_SPATIAL_SWAPCHAIN=1
# Detached, so closing this Terminal window doesn't take Steam with it.
nohup "$LAUNCHER" >/dev/null 2>&1 &!
