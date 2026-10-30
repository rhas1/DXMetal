#!/bin/zsh
# Prints details to include in a bug report: versions, the Mac, settings and status. It leaves out
# names, file paths and accounts.
set -euo pipefail
source "${0:A:h}/config.sh"

echo "Vapor $VAPOR_VERSION"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(sysctl -n machdep.cpu.brand_string)," \
  "$(( $(sysctl -n hw.memsize) / 1073741824 )) GB memory"
echo "Rosetta 2: $(arch -x86_64 /usr/bin/true 2>/dev/null && echo installed || echo missing)"
if [[ -x $LAUNCHER ]]; then
  r="$APP/Contents/SharedSupport/renderer"
  echo "Installed: $(installed_components)"
  echo "Pinned: $(pinned_components)"
  echo "Translators: DXMT $(cat "$r/dxmt/version" 2>/dev/null), D3DMetal" \
    "$(plutil -extract CFBundleShortVersionString raw "$r/d3dmetal/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null)"
  echo "Settings: $(describe_settings)"
  echo "Steam installed: $([[ -f $STEAM_DIR/steam.exe ]] && echo yes || echo no)"
elif [[ -x $LEGACY_APP/Contents/MacOS/wineskinlauncher ]]; then
  echo "Not installed; a DXMetal install is waiting to be moved"
else
  echo "Not installed"
fi
echo "Steam/Wine: $(pgrep -x wineserver >/dev/null && echo running || echo 'not running')"
running_games | sed 's/^/Running: /'
echo "Free space: $(df -Pk "${APP:h:h}" | awk 'NR == 2 {print int($4 / 1048576)}') GB"
echo "Shader caches: $(size_of "${CACHE_DIRS[@]}")"
