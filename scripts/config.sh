# Shared settings and helpers, sourced by the other scripts.

# Use macOS's own tools, not same-named ones that Homebrew or others put earlier in PATH.
PATH=/usr/bin:/bin:/usr/sbin:/sbin

VAPOR_VERSION=2.1.0  # this release; app/build.sh numbers the app with it

# Where Vapor Steam goes: the app that holds Wine, the translators and the Windows C: drive (Steam
# and your games). Spotlight skips folders whose names end in .noindex, so searching shows only the
# Vapor app. To use an external APFS drive, change the default path below before running setup.sh.
INSTALL_PATH="${INSTALL_PATH:-$HOME/Library/Application Support/Vapor.noindex/Vapor Steam.app}"
# Where earlier versions put it: Vapor 2.0, and DXMetal (Vapor's previous name). Until setup.sh
# moves an install from there, the scripts use it where it is.
OLD_APPS=("$HOME/Games/Vapor Steam.app" "$HOME/Games/DXMetal.app")
APP=$INSTALL_PATH
if [[ ! -e $APP ]]; then
  for place in "${OLD_APPS[@]}"; do
    if [[ -x $place/Contents/MacOS/wineskinlauncher ]]; then APP=$place; break; fi
  done
fi

# Pinned Sikarugir wrapper template and Wine 11 engine (built from CrossOver sources; the template
# ships the D3DMetal and DXMT translators). tools/update-pins.sh moves these to newer releases; when
# editing by hand, change each URL and its SHA-256 together.
TEMPLATE_URL="https://github.com/Sikarugir-App/Template/releases/download/v1.0/Template-1.0.24.tar.xz"
TEMPLATE_SHA256="4b5f89eeb9ef139936bdfad33d9b420b05ea4597cb7d63376674f7a8e171321c"
ENGINE_URL="https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineSikarugir11.0_1.tar.xz"
ENGINE_SHA256="67e29fb3d74f363af39c69ba11f9b13a79812c5db07cf4748672658e4a200a0e"
# Valve's current installer; Steam updates itself after installing, so this isn't pinned.
STEAM_SETUP_URL="https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"

LAUNCHER="$APP/Contents/MacOS/wineskinlauncher"
PLIST="$APP/Contents/Info.plist"
PREFIX_DIR="$APP/Contents/SharedSupport/prefix"  # Wine prefix: registry + C: drive
DRIVE_C="$APP/Contents/drive_c"
STEAM_DIR="$DRIVE_C/Program Files (x86)/Steam"
# The translators' shader caches, with a folder per game. Games rebuild them as needed.
CACHE_DIRS=("$(getconf DARWIN_USER_CACHE_DIR)"{d3dm,dxmt})

# Sets a wrapper setting, e.g. set_opt "Program Flags" string "-foo"
set_opt() { plutil -replace "$1" -"$2" "$3" "$PLIST"; }

# The template and engine an install was built from, which setup.sh records, and the ones pinned
# above. needs_update succeeds when they differ.
installed_components() { plutil -extract VAPOR_COMPONENTS raw "$PLIST" 2>/dev/null || true; }
pinned_components() { echo "${TEMPLATE_URL:t} ${ENGINE_URL:t}"; }
needs_update() { [[ $(installed_components) != "$(pinned_components)" ]]; }

# Stops unless the disk that holds (or will hold) $1 has at least $2 GB free.
need_space() {
  local dir=$1 free
  until [[ -d $dir ]]; do dir=${dir:h}; done
  free=$(df -Pk "$dir" | awk 'NR == 2 {print int($4 / 1048576)}')
  (( free >= $2 )) || { echo "Not enough free space: $free GB free, $2 GB needed."; exit 1; }
}

# The total size of the given files and folders, e.g. "49G". Missing ones count as nothing.
size_of() { du -shc "$@" 2>/dev/null | tail -1 | awk '{print $1}'; }

# Waits up to $1 seconds for all Wine processes to exit; fails if Wine is still running.
wait_for_wine() {
  local i
  for i in {1..$1}; do pgrep -x wineserver >/dev/null || return 0; sleep 1; done
  ! pgrep -x wineserver >/dev/null
}

# Downloads $1 to $2 and stops unless its SHA-256 matches $3.
fetch() {
  curl -fL --progress-bar -o "$2" "$1"
  [[ $(shasum -a 256 "$2" | cut -d' ' -f1) == "$3" ]] || { echo "Checksum mismatch for ${1:t}; not using it."; exit 1; }
}

# Sets value $2 under key $1 in Wine's HKEY_CURRENT_USER registry to the string $3, e.g.
# reg_set 'Software\Wine\Mac Driver' RetinaMode y. The registry is a text file that Wine only
# loads and saves while running, so this edits it directly (Wine must not be running).
reg_set() {
  local reg="$PREFIX_DIR/user.reg"
  KEY="[${1//\\/\\\\}]" NAME="\"$2\"=" LINE="\"$2\"=\"$3\"" awk -v now="$(date +%s)" '
    index($0, ENVIRON["KEY"]) == 1 { print; s = found = 1; next }
    s && index($0, ENVIRON["NAME"]) == 1 { next }
    s && (/^$/ || /^\[/) { print ENVIRON["LINE"]; s = 0 }
    { print }
    END {
      if (s) print ENVIRON["LINE"]
      if (!found) printf "\n%s %s\n%s\n", ENVIRON["KEY"], now, ENVIRON["LINE"]
    }' "$reg" > "$reg.tmp" && mv "$reg.tmp" "$reg"
}

# Resolution mode: 1 = full Retina resolution, 0 = scaled (faster). Stored as RetinaMode under
# HKCU\Software\Wine\Mac Driver, which Wine reads at startup.
get_retina() {
  [[ -f "$PREFIX_DIR/user.reg" ]] || { echo 0; return; }
  awk '/^\[Software\\\\Wine\\\\Mac Driver\]/ {s=1; next} /^\[/ {s=0} s && /^"RetinaMode"="[yYtT1]/ {r=1} END {print r+0}' \
    "$PREFIX_DIR/user.reg"
}
set_retina() { reg_set 'Software\Wine\Mac Driver' RetinaMode "$([[ $1 == 1 ]] && echo y || echo n)"; }

# Renderer: 1 = DXMT, 0 = D3DMetal (the wrapper's D3DMETAL flag is the inverse). Read by Steam at startup.
get_dxmt() { echo $(( 1 - $(plutil -extract D3DMETAL raw "$PLIST") )); }
set_dxmt() { set_opt D3DMETAL integer $(( 1 - $1 )); }

# Metal performance HUD (FPS overlay) in games: 1 = on, 0 = off. Read by Steam at startup.
get_hud() { plutil -extract METAL_HUD raw "$PLIST"; }
set_hud() { set_opt METAL_HUD integer "$1"; }

# MetalFX spatial upscaling of each frame to 2x: 1 = on, 0 = off. Stored in our own Info.plist key
# (DXMETAL_METALFX in installs made by DXMetal). DXMT only, and meant for scaled resolution.
get_metalfx() {
  plutil -extract VAPOR_METALFX raw "$PLIST" 2>/dev/null || plutil -extract DXMETAL_METALFX raw "$PLIST" 2>/dev/null ||
    echo 0
}
set_metalfx() { set_opt VAPOR_METALFX integer "$1"; }
metalfx_active() { (( $(get_metalfx) && $(get_dxmt) && ! $(get_retina) )); }

# The wrapper runs its "CLI Custom Commands" setting before starting Wine, so exporting MetalFX's
# variable there applies it however Steam is started, including a double-click on the app.
apply_metalfx() {
  local cmds nl=$'\n'
  cmds=$(plutil -extract "CLI Custom Commands" raw "$PLIST" 2>/dev/null | grep -v DXMT_METALFX_SPATIAL_SWAPCHAIN || true)
  metalfx_active && cmds+="${cmds:+$nl}export DXMT_METALFX_SPATIAL_SWAPCHAIN=1"
  set_opt "CLI Custom Commands" string "$cmds"
}

# Saves the settings RETINA DXMT HUD METALFX, each 0 or 1. Steam only reads them when it starts,
# so Wine must not be running.
save_settings() {
  if [[ $1 != $(get_retina) ]]; then
    set_retina $1
    echo "Resolution mode changed: pick the resolution again in the game's display settings."
  fi
  set_dxmt $2
  set_hud $3
  set_metalfx $4
  apply_metalfx
}

describe_settings() {
  local metalfx=off
  (( $(get_metalfx) )) && { metalfx_active && metalfx=on || metalfx="on, but inactive (needs DXMT and scaled resolution)"; }
  echo "$( (( $(get_retina) )) && echo Retina || echo scaled) resolution," \
    "$( (( $(get_dxmt) )) && echo DXMT || echo D3DMetal)," \
    "HUD $( (( $(get_hud) )) && echo on || echo off)," \
    "MetalFX $metalfx"
}

# Lists running games (Wine processes drawing with DirectX, Vulkan or OpenGL) as "name on renderer".
running_games() {
  local pid name files r
  for pid in $(pgrep -f '\.exe' || true); do
    name=$(ps -o command= -p $pid | grep -oE '[^\\]+\.exe' | head -1 || true)
    [[ $name == (steam*|gameoverlayui*|services|winedevice|plugplay|svchost|explorer|rpcss|conhost|start|wineboot).exe ]] && continue
    files=$(lsof -p $pid 2>/dev/null || true)
    if grep -q 'D3DMetal.framework' <<<"$files"; then r=D3DMetal
    elif grep -q 'renderer/dxmt/' <<<"$files"; then r=DXMT
    elif grep -q 'renderer/d9vk/' <<<"$files"; then r="D9VK (DirectX 9 via Vulkan)"
    elif grep -q 'renderer/dxvk' <<<"$files"; then r="DXVK (via Vulkan)"
    elif grep -qiE '(d3d9|d3d10|d3d11|d3d12)\.dll' <<<"$files"; then r="Wine's built-in DirectX (slow)"
    elif grep -qi 'winevulkan' <<<"$files"; then r="Vulkan (via MoltenVK)"
    elif grep -qi 'opengl32\.dll' <<<"$files"; then r=OpenGL
    else continue; fi
    echo "$name on $r"
  done
}

# Runs a Windows program inside the already-running Wine session (e.g. to message Steam),
# with the core of the environment the wrapper's launcher uses. This Wine build silently
# exits unless SikarugirAppWine11 is set, and must match the session's msync mode.
wine_exec() (
  local wine="$APP/Contents/SharedSupport/wine" fw="$APP/Contents/Frameworks"
  export SikarugirAppWine11=1 CX_ROOT="$wine" WINEPREFIX="$PREFIX_DIR" WINEMSYNC=1 WINEDEBUG=-all \
    WINEDLLPATH="$wine/lib/x86_64-windows:$wine/lib/i386-windows:$wine/lib/x86_64-unix" \
    DYLD_FALLBACK_LIBRARY_PATH="$wine/lib:$wine/lib64:$fw:$fw/GStreamer.framework/Versions/1.0/lib:/usr/lib"
  "$wine/bin/wine" "$@"
)
