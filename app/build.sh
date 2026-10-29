#!/bin/zsh
# Builds "DXMetal Settings.app" and a disk image of it into app/build. Building needs Apple's Command
# Line Tools (xcode-select --install); the finished app runs on any Apple Silicon Mac without them.
set -euo pipefail
version=1.0.0  # released as tag v1.0.0
here=${0:A:h}
out="$here/build"
app="$out/DXMetal Settings.app"
dmg="$out/DXMetal-Settings-$version.dmg"

command -v swiftc >/dev/null || { echo "This needs Apple's Command Line Tools: run xcode-select --install"; exit 1; }
rm -rf "$out"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/scripts"
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14.0 \
  -o "$app/Contents/MacOS/DXMetal Settings" "$here/DXMetalSettings.swift"
# The app runs the same scripts as the command line.
cp "$here"/../scripts/{config,setup,run-steam,close-wine}.sh "$app/Contents/Resources/scripts/"
cp "$here/AppIcon.icns" "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>DXMetal Settings</string>
  <key>CFBundleDisplayName</key><string>DXMetal Settings</string>
  <key>CFBundleExecutable</key><string>DXMetal Settings</string>
  <key>CFBundleIdentifier</key><string>io.github.rhas1.dxmetal.settings</string>
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
# Apple Silicon only runs signed code, so sign it for this Mac ("ad hoc"); signing refuses files
# that carry Finder metadata. It isn't notarized: a copy that arrives by download or AirDrop needs
# approving once in Privacy & Security settings.
xattr -cr "$app"
codesign --force --sign - --options runtime "$app"

# The disk image to publish or send to another Mac: the app, plus a shortcut to drag it onto
# Applications. It leaves out file metadata that this Mac adds (for example in a synced Documents
# folder), which would also break the signature's strict check.
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto --norsrc --noextattr "$app" "$stage/DXMetal Settings.app"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -volname "DXMetal Settings $version" -srcfolder "$stage" -format UDZO -ov "$dmg"

echo "Built $app"
echo "Disk image: $dmg"
echo "SHA-256: $(shasum -a 256 "$dmg" | cut -d' ' -f1)"
