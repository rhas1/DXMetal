#!/bin/zsh
# Builds DXMetal.app (Wine + renderers) and installs Windows Steam into it.
# Safe to run again: finished steps are skipped and your settings are kept.
set -euo pipefail
source "${0:A:h}/config.sh"

autoload -Uz is-at-least
[[ $(uname -m) == arm64 ]] || { echo "This needs a Mac with Apple Silicon (M1 or newer)."; exit 1; }
is-at-least 14.6 "$(sw_vers -productVersion)" || { echo "This needs macOS 14.6 or newer."; exit 1; }

arch -x86_64 /usr/bin/true 2>/dev/null || {
  echo "Installing Rosetta 2 (this accepts Apple's Rosetta license)..."
  softwareupdate --install-rosetta --agree-to-license
}

# The wrapper's launcher waits for *any* wineserver to exit, so it would hang.
pgrep -x wineserver >/dev/null && { echo "Quit Steam/Wine first (${0:h}/close-wine.sh)."; exit 1; }

if [[ ! -x "$LAUNCHER" ]]; then
  [[ -e "$APP" ]] && { echo "$APP exists but isn't a complete DXMetal app. Move or delete it, then run this again."; exit 1; }
  echo "Downloading the wrapper and Wine..."
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  fetch "$TEMPLATE_URL" "$tmp/template.tar.xz" "$TEMPLATE_SHA256"
  fetch "$ENGINE_URL" "$tmp/engine.tar.xz" "$ENGINE_SHA256"
  tar -xJf "$tmp/template.tar.xz" -C "$tmp"
  tar -xJf "$tmp/engine.tar.xz" -C "$tmp"
  mkdir -p "${APP:h}"
  mv "$tmp"/Template-*.app "$APP"
  mv "$tmp/wswine.bundle" "$APP/Contents/SharedSupport/wine"
  # Defaults: D3DMetal, no FPS overlay, quiet Wine logging. Wine starts in scaled resolution.
  set_opt D3DMETAL integer 1
  set_opt METAL_HUD integer 0
  set_opt WINEDEBUG string "-all"
fi

if [[ ! -f "$PREFIX_DIR/system.reg" ]]; then
  echo "Creating the Windows environment..."
  "$LAUNCHER" WSS-wineprefixcreate
fi

if [[ ! -f "$STEAM_DIR/steam.exe" ]]; then
  echo "Installing Windows Steam..."
  curl -fL --progress-bar -o "$DRIVE_C/SteamSetup.exe" "$STEAM_SETUP_URL"
  set_opt "Program Name and Path" string "/SteamSetup.exe"
  set_opt "Program Flags" string "/S"
  "$LAUNCHER"
  "$LAUNCHER" WSS-wineserverkill >/dev/null 2>&1 || true
  rm -f "$DRIVE_C/SteamSetup.exe"
fi
set_opt "Program Name and Path" string "/Program Files (x86)/Steam/steam.exe"
set_opt "Program Flags" string ""

# Mark the app as a game for macOS Game Mode, and keep Wine and games out of Time Machine.
set_opt LSApplicationCategoryType string "public.app-category.games"
set_opt LSSupportsGameMode bool true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true
tmutil addexclusion "$APP" 2>/dev/null || echo "Note: couldn't exclude the app from Time Machine backups."

echo "Done. Start Steam with ${0:h}/run-steam.sh (or double-click $APP)."
