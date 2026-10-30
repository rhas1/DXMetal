#!/bin/zsh
# Checks for and installs new versions of the Vapor app, from its GitHub releases.
#   update-app.sh check                 prints the latest version, e.g. 2.0.1
#   update-app.sh download VERSION DIR  downloads that version into DIR, checks it against the
#                                       release's SHA256SUMS, and prints the disk image's path
#   update-app.sh replace DMG APP PID   waits for process PID (the app) to quit, replaces APP with
#                                       the copy in DMG, and opens it
set -euo pipefail
PATH=/usr/bin:/bin:/usr/sbin:/sbin
repo=rhas1/Vapor

case ${1:-} in
check)
  curl -fsSL --max-time 20 -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$repo/releases/latest" | plutil -extract tag_name raw - | sed 's/^v//'
  ;;
download)
  url="https://github.com/$repo/releases/download/v$2"
  { curl -fsSL --max-time 600 -o "$3/Vapor-$2.dmg" "$url/Vapor-$2.dmg" &&
    curl -fsSL --max-time 30 -o "$3/SHA256SUMS" "$url/SHA256SUMS"; } 2>/dev/null ||
    { echo "Couldn't download Vapor $2 from GitHub. Check your internet connection and try again."; exit 1; }
  (cd "$3" && shasum -a 256 -c SHA256SUMS >/dev/null 2>&1) ||
    { echo "The download doesn't match its checksum, so it wasn't installed."; exit 1; }
  echo "$3/Vapor-$2.dmg"
  ;;
replace)
  while kill -0 "$4" 2>/dev/null; do sleep 0.5; done
  mnt=$(mktemp -d)
  hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mnt" "$2" || { open "$2"; exit 1; }
  # Keep the old copy until the new one is in place.
  replaced=0
  if mv "$3" "$3.old" 2>/dev/null; then
    if ditto "$mnt/Vapor.app" "$3"; then rm -rf "$3.old"; replaced=1; else rm -rf "$3"; mv "$3.old" "$3"; fi
  fi
  hdiutil detach -quiet "$mnt" || true
  # If it couldn't be replaced (for example without permission to change Applications), show the
  # disk image so it can be dragged in by hand.
  (( replaced )) || open "$2"
  open "$3"
  ;;
*)
  echo "Usage: ${0:t} check | download VERSION DIR | replace DMG APP PID"
  exit 1
  ;;
esac
