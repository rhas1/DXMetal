#!/bin/zsh
# Removes Vapor Steam, including Steam, installed games and saved sign-ins, and the translators'
# shader caches, after asking you to confirm. Also removes installs where earlier versions put them
# (including DXMetal, Vapor's previous name). Run setup.sh afterwards to install again.
set -euo pipefail
source "${0:A:h}/config.sh"

# Only ever delete something that is actually a Vapor or DXMetal install.
apps=()
for a in "$INSTALL_PATH" "${OLD_APPS[@]}"; do [[ -x $a/Contents/MacOS/wineskinlauncher ]] && apps+=("$a"); done
(( $#apps )) || { echo "Nothing to remove: Vapor Steam isn't installed."; exit 0; }
pgrep -x wineserver >/dev/null && { echo "Quit Steam first (${0:h}/close-wine.sh)."; exit 1; }

echo "This deletes $(size_of "${apps[@]}" "${CACHE_DIRS[@]}"): ${apps[*]}, including Steam, all installed"
echo "games, your sign-ins and any saves stored only on this Mac, plus the shader caches."
read "?Uninstall? [y/N] " ans || ans=n
[[ $ans == [yY] ]] || { echo "Nothing removed."; exit 0; }
rm -rf "${apps[@]}" "${INSTALL_PATH:h}/.vapor-update" "${OLD_APPS[1]:h}/.vapor-update" "${CACHE_DIRS[@]}"
rmdir "${INSTALL_PATH:h}" 2>/dev/null || true  # the folder it was in, if nothing else is there
echo "Removed. Run ${0:h}/setup.sh to install again."
