#!/bin/zsh
# Deletes the translators' shader caches, after asking you to confirm. Games rebuild them as you
# play, so expect some stutter the first time through each area. Steam must be closed.
set -euo pipefail
source "${0:A:h}/config.sh"

pgrep -x wineserver >/dev/null && { echo "Quit Steam first (${0:h}/close-wine.sh)."; exit 1; }
size=$(size_of "${CACHE_DIRS[@]}")
read "?Delete $size of shader caches? [y/N] " ans || ans=n
[[ $ans == [yY] ]] || { echo "Nothing deleted."; exit 0; }
rm -rf "${CACHE_DIRS[@]}"
echo "Cleared $size of shader caches."
