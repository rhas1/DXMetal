# Shared settings and helpers, sourced by the other scripts.

# Where the app lives. It holds Wine, the renderers and the Windows C: drive (Steam and games).
# To use an external APFS drive, change the default path below before running setup.sh.
APP="${APP:-$HOME/Games/DXMetal.app}"

# Pinned Sikarugir wrapper template and Wine 11 engine (built from CrossOver sources; they ship
# the D3DMetal and DXMT renderers). When updating, change each URL and its SHA-256 together.
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

# Sets a wrapper setting, e.g. set_opt "Program Flags" string "-foo"
set_opt() { plutil -replace "$1" -"$2" "$3" "$PLIST"; }

# Downloads $1 to $2 and stops unless its SHA-256 matches $3.
fetch() {
  curl -fL --progress-bar -o "$2" "$1"
  [[ $(shasum -a 256 "$2" | cut -d' ' -f1) == "$3" ]] || { echo "Checksum mismatch for ${1:t}; not using it."; exit 1; }
}

# Resolution mode: 1 = full Retina resolution, 0 = scaled (faster). Stored as RetinaMode under
# HKCU\Software\Wine\Mac Driver, which Wine reads at startup. The registry is a text file that
# Wine only loads/saves while running, so we edit it directly (Wine must not be running).
get_retina() {
  [[ -f "$PREFIX_DIR/user.reg" ]] || { echo 0; return; }
  awk '/^\[Software\\\\Wine\\\\Mac Driver\]/ {s=1; next} /^\[/ {s=0} s && /^"RetinaMode"="[yYtT1]/ {r=1} END {print r+0}' \
    "$PREFIX_DIR/user.reg"
}
set_retina() {
  local reg="$PREFIX_DIR/user.reg"
  awk -v val="$([[ $1 == 1 ]] && echo y || echo n)" -v now="$(date +%s)" '
    /^\[Software\\\\Wine\\\\Mac Driver\]/ { print; s = found = 1; next }
    s && /^"RetinaMode"=/ { next }
    s && (/^$/ || /^\[/) { print "\"RetinaMode\"=\"" val "\""; s = 0 }
    { print }
    END {
      if (s) print "\"RetinaMode\"=\"" val "\""
      if (!found) printf "\n[Software\\\\Wine\\\\Mac Driver] %s\n\"RetinaMode\"=\"%s\"\n", now, val
    }' "$reg" > "$reg.tmp" && mv "$reg.tmp" "$reg"
}

# Renderer: 1 = DXMT, 0 = D3DMetal (the wrapper's D3DMETAL flag is the inverse). Read by Steam at startup.
get_dxmt() { echo $(( 1 - $(plutil -extract D3DMETAL raw "$PLIST") )); }
set_dxmt() { set_opt D3DMETAL integer $(( 1 - $1 )); }

# Metal performance HUD (FPS overlay) in games: 1 = on, 0 = off. Read by Steam at startup.
get_hud() { plutil -extract METAL_HUD raw "$PLIST"; }
set_hud() { set_opt METAL_HUD integer "$1"; }

describe_settings() {
  echo "$( (( $(get_retina) )) && echo Retina || echo scaled) resolution," \
    "$( (( $(get_dxmt) )) && echo DXMT || echo D3DMetal)," \
    "HUD $( (( $(get_hud) )) && echo on || echo off)"
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
