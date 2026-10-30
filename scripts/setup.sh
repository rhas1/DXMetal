#!/bin/zsh
# Installs Vapor Steam (Wine, the translators and Windows Steam), or updates it to the versions
# pinned in config.sh. Updating keeps Steam, your games, sign-ins and settings, and also moves an
# install over from DXMetal, Vapor's previous name. Safe to run again: finished steps are skipped.
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

# The install to keep, if any: this one, or one made by DXMetal.
old=
if [[ -x $LAUNCHER ]]; then old=$APP
elif [[ -x $LEGACY_APP/Contents/MacOS/wineskinlauncher ]]; then old=$LEGACY_APP
elif [[ -e $APP ]]; then echo "$APP exists but isn't a complete Vapor install. Move or delete it, then run this again."; exit 1
fi

# Builds a fresh wrapper next to the install, so moving the Windows drive into it is instant.
stage="${APP:h}/.vapor-update"
new="$stage/new.app"
for p in "$stage"/*.app/Contents/SharedSupport/prefix(N); do
  echo "An earlier update didn't finish, and your Windows drive (Steam and games) is still in:"
  echo "  $p"
  echo "See \"An update stopped partway\" under Troubleshooting in the README to put it back."
  exit 1
done

# Copies your settings from one Info.plist ($1) to another ($2).
carry_settings() {
  local key val
  for key in D3DMETAL METAL_HUD; do
    val=$(plutil -extract $key raw "$1" 2>/dev/null) && plutil -replace $key -integer "$val" "$2"
  done
  val=$(plutil -extract VAPOR_METALFX raw "$1" 2>/dev/null || plutil -extract DXMETAL_METALFX raw "$1" 2>/dev/null || echo 0)
  plutil -replace VAPOR_METALFX -integer "$val" "$2"
  val=$(plutil -extract "CLI Custom Commands" raw "$1" 2>/dev/null || true)
  plutil -replace "CLI Custom Commands" -string "$val" "$2"
}

# A fresh wrapper is needed to install, when the pinned versions change, or to move a DXMetal install.
if [[ $old != $APP ]] || needs_update; then
  if [[ -n $old ]]; then
    echo "Updating to ${TEMPLATE_URL:t:r:r} and ${ENGINE_URL:t:r:r}. Steam, your games and settings stay."
    need_space "$APP" 3
  else
    echo "Downloading the wrapper and Wine..."
    need_space "$APP" 5
  fi
  tmp=$(mktemp -d)
  moved=0
  # If anything fails after the Windows drive moved, put it and the old install back. The staging
  # folder is only deleted once no Windows drive is left in it.
  cleanup() {
    if (( moved )) && [[ -d $new/Contents/SharedSupport/prefix ]]; then
      [[ -d $stage/old.app ]] && mv "$stage/old.app" "$old"
      mv "$new/Contents/SharedSupport/prefix" "$old/Contents/SharedSupport/prefix"
    fi
    rm -rf "$tmp"
    [[ -z $(print -l "$stage"/*.app/Contents/SharedSupport/prefix(N)) ]] && rm -rf "$stage"
  }
  trap cleanup EXIT
  fetch "$TEMPLATE_URL" "$tmp/template.tar.xz" "$TEMPLATE_SHA256"
  fetch "$ENGINE_URL" "$tmp/engine.tar.xz" "$ENGINE_SHA256"
  tar -xJf "$tmp/template.tar.xz" -C "$tmp"
  tar -xJf "$tmp/engine.tar.xz" -C "$tmp"
  rm -rf "$stage"
  mkdir -p "$stage"
  mv "$tmp"/Template-*.app "$new"
  mv "$tmp/wswine.bundle" "$new/Contents/SharedSupport/wine"
  if [[ -n $old ]]; then
    carry_settings "$old/Contents/Info.plist" "$new/Contents/Info.plist"
    rm -rf "$new/Contents/SharedSupport/prefix"
    moved=1
    mv "$old/Contents/SharedSupport/prefix" "$new/Contents/SharedSupport/prefix"
    # Wine keeps some paths into the old wrapper in its registry. This makes it refresh them when
    # Steam next starts (refreshing now would also start Steam, which runs at Windows login).
    rm -f "$new/Contents/SharedSupport/prefix/.update-timestamp"
    mv "$old" "$stage/old.app"
  fi
  mkdir -p "${APP:h}"
  mv "$new" "$APP"
  moved=0
  [[ -L $DRIVE_C ]] || ln -s SharedSupport/prefix/drive_c "$DRIVE_C"
  # macOS checks a new app the first time it runs, and holds it for a couple of minutes while it
  # does. Running a harmless launcher command now gets that done here, so Steam then starts quickly.
  echo "Letting macOS check the new wrapper (this can take a couple of minutes)..."
  "$LAUNCHER" WSS-wineserverkill >/dev/null 2>&1 || true
  if [[ -z $old ]]; then
    # Defaults: DXMT, no FPS overlay, no MetalFX. Wine starts in scaled resolution.
    set_dxmt 1
    set_hud 0
    set_metalfx 0
  fi
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
  # The launcher only waits for a program when no Wine is running, and Wine lingers for a few
  # seconds after creating the Windows environment; starting too early cuts the installer off.
  wait_for_wine 60 || { echo "Wine is still running; run ${0:h}/close-wine.sh and try again."; exit 1; }
  "$LAUNCHER"
  wait_for_wine 120 || "$LAUNCHER" WSS-wineserverkill >/dev/null 2>&1 || true
  rm -f "$DRIVE_C/SteamSetup.exe"
fi
[[ -f "$STEAM_DIR/steam.exe" ]] || { echo "Steam didn't install. Run setup again; if that fails, see Troubleshooting in the README."; exit 1; }
set_opt "Program Name and Path" string "/Program Files (x86)/Steam/steam.exe"
set_opt "Program Flags" string ""
set_opt WINEDEBUG string "-all"
apply_metalfx

# The app holds your Steam and game sign-ins, and the wrapper ships with parts of it world-writable:
# keep other accounts on this Mac out of it. Also keep Wine and games out of Time Machine.
chmod 700 "$APP"
tmutil addexclusion "$APP" 2>/dev/null || echo "Note: couldn't exclude the app from Time Machine backups."
set_opt VAPOR_COMPONENTS string "$(pinned_components)"

echo "Done. Start Steam from the Vapor app, with ${0:h}/run-steam.sh, or by double-clicking $APP."
