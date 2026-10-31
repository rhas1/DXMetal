#!/bin/zsh
# Starts Windows Steam, optionally changing settings first.
# Usage: ./run-steam.sh [RETINA [DXMT [HUD [METALFX [FPS [OVERLAY]]]]]]   (settings you leave off stay as they are)
#   RETINA   0 = scaled resolution (faster), 1 = full Retina resolution
#   DXMT     0 = D3DMetal, 1 = DXMT
#   HUD      0 = off, 1 = Metal performance overlay (FPS) in games
#   METALFX  0 = off, 1 = MetalFX upscales each frame 2x (DXMT at scaled resolution only)
#   FPS      0 = no frame-rate limit, 30 or 60 = limit games to that many frames per second
#   OVERLAY  0 = Steam's in-game overlay off (it can freeze games under Wine), 1 = on
# e.g. ./run-steam.sh 0 1 0 1 30
set -euo pipefail
source "${0:A:h}/config.sh"

[[ -f "$STEAM_DIR/steam.exe" ]] || { echo "Vapor Steam isn't installed yet; run ${0:h}/setup.sh first."; exit 1; }

self=$0  # inside functions, $0 is the function's name
usage() { echo "Usage: $self [RETINA [DXMT [HUD [METALFX [FPS [OVERLAY]]]]]]: FPS is 0, 30 or 60, the others 0 or 1 (e.g. $self 0 1 0 1 30)"; exit 1; }
(( $# <= 6 )) || usage
for (( i = 1; i <= $#; i++ )); do
  if (( i == 5 )); then [[ ${@[i]} == (0|30|60) ]] || usage
  else [[ ${@[i]} == [01] ]] || usage; fi
done

current=($(get_retina) $(get_dxmt) $(get_hud) $(get_metalfx) $(get_fps_limit) $(get_overlay))
wanted=("$@" "${(@)current[$#+1,-1]}")
if [[ "$wanted" != "$current" ]]; then
  # All settings are only read when Steam/Wine starts.
  pgrep -x wineserver >/dev/null &&
    { echo "Steam is running with $(describe_settings). Quit it first (${0:h}/close-wine.sh)."; exit 1; }
  save_settings $wanted
fi
# Keep the wrapper and Steam in step with the settings, e.g. after updating these scripts, or after
# turning the overlay back on in Steam's own settings. Steam rewrites its settings while it runs.
apply_env
pgrep -x wineserver >/dev/null || apply_overlay

echo "Steam: $(describe_settings)"
# Detached, so closing this Terminal window doesn't take Steam with it.
nohup "$LAUNCHER" >/dev/null 2>&1 &!
