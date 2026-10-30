#!/bin/zsh
# Points scripts/config.sh at the newest Sikarugir wrapper template and Wine 11 engine, with fresh
# SHA-256 checksums. With --bump, a change also raises the patch version and adds a CHANGELOG entry,
# ready to release. The daily "Update pins" GitHub Action runs it with --bump and opens a pull
# request; you can also run it by hand. Needs macOS (for its sed), curl, jq and shasum.
set -euo pipefail
root=${0:A:h}/..
cfg=$root/scripts/config.sh
auth=()
[[ -n ${GITHUB_TOKEN:-} ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

# Prints the download URL of the newest file (by upload date) in $1's releases whose name matches
# the regular expression $2.
newest() {
  curl -fsSL "${auth[@]}" "https://api.github.com/repos/$1/releases?per_page=100" |
    jq -r --arg re "$2" '[.[].assets[] | select(.name | test($re))] | sort_by(.created_at) | last | .browser_download_url // empty'
}

changes=()
# Points $1 (TEMPLATE or ENGINE) at the URL $2 and its checksum.
pin() {
  local current file sha
  current=$(sed -n "s/^$1_URL=\"\(.*\)\"$/\1/p" "$cfg")
  [[ -n $2 ]] || { echo "$1: no release found"; exit 1; }
  if [[ $current == $2 ]]; then echo "$1: ${2:t} is current"; return; fi
  file=$(mktemp)
  curl -fsSL -o "$file" "$2"
  sha=$(shasum -a 256 "$file" | cut -d' ' -f1)
  rm -f "$file"
  sed -i '' -e "s|^$1_URL=.*|$1_URL=\"$2\"|" -e "s|^$1_SHA256=.*|$1_SHA256=\"$sha\"|" "$cfg"
  echo "$1: ${current:t} -> ${2:t}"
  changes+=("${2:t:r:r}")
}

pin TEMPLATE "$(newest Sikarugir-App/Template '^Template-[0-9.]+\.tar\.xz$')"
pin ENGINE "$(newest Sikarugir-App/Engines '^WS12WineSikarugir11\.[0-9._]+\.tar\.xz$')"

if [[ ${1:-} == --bump ]] && (( $#changes )); then
  version=$(sed -n 's/^VAPOR_VERSION=\([0-9.]*\).*/\1/p' "$cfg")
  next=${version%.*}.$(( ${version##*.} + 1 ))
  # The new entry goes above the newest one. It's passed through the environment because macOS's
  # awk rejects values with line breaks in -v.
  ENTRY="## [$next] - $(date +%Y-%m-%d)

### Changed

- Updated to ${(j: and :)changes}. Vapor offers the update when you open it; Steam, your games and settings stay.
" awk '!done && /^## \[/ {print ENVIRON["ENTRY"]; done = 1} {print}' "$root/CHANGELOG.md" > "$root/CHANGELOG.md.new"
  echo "[$next]: https://github.com/rhas1/Vapor/releases/tag/v$next" >> "$root/CHANGELOG.md.new"
  mv "$root/CHANGELOG.md.new" "$root/CHANGELOG.md"
  sed -i '' "s/^VAPOR_VERSION=$version/VAPOR_VERSION=$next/" "$cfg"
  echo "Version: $version -> $next"
fi
