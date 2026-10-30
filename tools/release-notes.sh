#!/bin/zsh
# Prints the GitHub release notes for version $1: its CHANGELOG section, how to install, and the
# disk image's SHA-256 ($2). The Release workflow uses it.
set -euo pipefail
v=$1 sha=$2

echo "## What's new"
awk -v v="$v" 'index($0, "## [" v "]") == 1 {on = 1; next} on && /^## \[/ {exit} on && !/^\[[^]]*\]: / {print}' \
  "${0:A:h}/../CHANGELOG.md"
cat <<EOF
## Install

1. Download **Vapor-$v.dmg** below, open it, and drag **Vapor** onto **Applications**.
2. Open Vapor. macOS blocks the first launch because Vapor isn't notarized: go to **System Settings → Privacy & Security** and click **Open Anyway**.
3. Click **Install**, or **Move to Vapor** if you used DXMetal. Then click **Start Steam**, sign in, and install your games.

Already using Vapor? Choose **More → Check for Updates…** in the app.

**Requirements:** a Mac with Apple Silicon running macOS 14.6 or newer, and about 5 GB of free space plus room for your games. Known limitations are listed in the [README](https://github.com/rhas1/Vapor/blob/v$v/README.md).

## Check the download

\`shasum -a 256 Vapor-$v.dmg\` should print:

\`\`\`
$sha  Vapor-$v.dmg
\`\`\`

The same line is in \`SHA256SUMS\` below, so \`shasum -a 256 -c SHA256SUMS\` checks it for you.
EOF
