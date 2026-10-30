#!/bin/zsh
# Builds Vapor.app and a disk image of it into app/build. Building needs Apple's Command Line
# Tools (xcode-select --install); the finished app runs on any Apple Silicon Mac without them.
set -euo pipefail
here=${0:A:h}
version=$(sed -n 's/^VAPOR_VERSION=\([0-9.]*\).*/\1/p' "$here/../scripts/config.sh")
out="$here/build"

command -v swiftc >/dev/null || { echo "This needs Apple's Command Line Tools: run xcode-select --install"; exit 1; }
# Build in a temporary folder, then copy the results to app/build: a synced folder (like Documents
# in iCloud) adds Finder metadata to new files as they appear, and signing refuses files with it.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
app="$work/Vapor.app"
dmg="$work/Vapor-$version.dmg"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/scripts"
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14.0 \
  -o "$app/Contents/MacOS/Vapor" "$here/Vapor.swift"
# The app runs the same scripts as the command line, plus its own updater.
cp "$here"/../scripts/{config,setup,run-steam,close-wine,uninstall,clear-caches,diagnostics}.sh \
  "$here/update-app.sh" "$app/Contents/Resources/scripts/"
cp "$here/AppIcon.icns" "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Vapor</string>
  <key>CFBundleDisplayName</key><string>Vapor</string>
  <key>CFBundleExecutable</key><string>Vapor</string>
  <key>CFBundleIdentifier</key><string>io.github.rhas1.vapor</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
# Apple Silicon only runs signed code, so sign it for this Mac ("ad hoc"), without the Finder
# metadata that copying from a synced folder can bring along. It isn't notarized: a copy that
# arrives by download or AirDrop needs approving once in Privacy & Security settings.
xattr -cr "$app"
codesign --force --sign - --options runtime "$app"

# The disk image to publish or send to another Mac: the app, a shortcut to drag it onto
# Applications, and the window's background and layout from app/dmg (tools/dmg-window.sh makes
# them; Finder finds the background by the disk's name, so that stays "Vapor"). It leaves out file
# metadata, which would also break the signature's strict check.
stage="$work/disk"
mkdir -p "$stage/.background"
ditto --norsrc --noextattr "$app" "$stage/Vapor.app"
ln -s /Applications "$stage/Applications"
cp -X "$here/dmg/background.tiff" "$stage/.background/"
cp -X "$here/dmg/DS_Store" "$stage/.DS_Store"
hdiutil create -quiet -volname Vapor -fs HFS+ -srcfolder "$stage" -format UDZO "$dmg"

rm -rf "$out"
mkdir -p "$out"
ditto "$app" "$out/Vapor.app"
mv "$dmg" "$out/"
echo "Built $out/Vapor.app"
echo "Disk image: $out/${dmg:t}"
echo "SHA-256: $(shasum -a 256 "$out/${dmg:t}" | cut -d' ' -f1)"
