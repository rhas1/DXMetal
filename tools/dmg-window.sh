#!/bin/zsh
# Makes the look of the disk image's window, into app/dmg: draws its background with
# dmg-background.swift, then has Finder lay out a scratch disk image like the real one and keeps the
# layout file (.DS_Store) it saves, minus what it says about this Mac (clean-dsstore.py). app/build.sh
# copies both into every disk image, so run this on a Mac only after changing the design, then
# commit app/dmg. macOS asks once to let it control Finder.
set -euo pipefail
PATH=/usr/bin:/bin:/usr/sbin:/sbin
here=${0:A:h}
out="$here/../app/dmg"

[[ -d /Volumes/Vapor ]] && { echo "Eject the disk named Vapor first: Finder finds disks by name."; exit 1; }
# Detaches a disk image, forcing it if Spotlight is still reading it. A scratch disk left attached
# would keep its name, and Finder would show its background in place of the real disk's.
detach() { hdiutil detach -quiet "$1" 2>/dev/null || { sleep 2; hdiutil detach -quiet -force "$1"; }; }
tmp=$(mktemp -d)
mnt=
trap '[[ -d /Volumes/Vapor ]] && detach /Volumes/Vapor; [[ -n $mnt ]] && detach "$mnt"; rm -rf "$tmp"' EXIT

# The background, at normal and Retina resolution in one file.
swiftc -O -o "$tmp/dmg-background" "$here/dmg-background.swift"
"$tmp/dmg-background" "$tmp/background.png" 1
"$tmp/dmg-background" "$tmp/background@2x.png" 2
mkdir -p "$out"
tiffutil -cathidpicheck "$tmp/background.png" "$tmp/background@2x.png" -out "$out/background.tiff"

# Finder records the background by disk name and path, and icon positions by file name, so the
# scratch disk matches the real one in those. Spotlight stays out of it, so it doesn't list the
# stand-in Vapor.app or keep the disk busy.
mkdir -p "$tmp/disk/.background" "$tmp/disk/Vapor.app"
cp -X "$out/background.tiff" "$tmp/disk/.background/"
ln -s /Applications "$tmp/disk/Applications"
touch "$tmp/disk/.metadata_never_index"
hdiutil create -quiet -volname Vapor -fs HFS+ -srcfolder "$tmp/disk" -format UDRW "$tmp/layout.dmg"
hdiutil attach -quiet -readwrite -noverify -noautoopen "$tmp/layout.dmg"

# The window shows 640 x 400 points of content below macOS 26's 32-point title bar (older versions'
# 28-point one leaves 404, which the background also covers), with the icons where
# dmg-background.swift draws around them. Hidden files go out of sight, for people who show them.
# Ejecting the disk makes Finder save the layout.
osascript <<'EOF'
tell application "Finder"
  tell disk "Vapor"
    open
    tell container window
      set current view to icon view
      set toolbar visible to false
      set statusbar visible to false
      try
        set pathbar visible to false
      end try
      set bounds to {415, 240, 1055, 672}
    end tell
    set options to icon view options of container window
    set arrangement of options to not arranged
    set icon size of options to 128
    set text size of options to 13
    set shows item info of options to false
    set shows icon preview of options to false
    set background picture of options to file ".background:background.tiff"
    set position of item "Vapor.app" of container window to {170, 200}
    set position of item "Applications" of container window to {470, 200}
    repeat with dotFile in {".background", ".fseventsd", ".DS_Store"}
      try
        set position of item dotFile of container window to {320, 700}
      end try
    end repeat
    update without registering applications
    delay 2
    close
  end tell
  eject disk "Vapor"
end tell
EOF

for i in {1..60}; do [[ -d /Volumes/Vapor ]] || break; sleep 0.5; done
mnt=$(mktemp -d)
hdiutil attach -quiet -readonly -nobrowse -noverify -mountpoint "$mnt" "$tmp/layout.dmg"
cp -X "$mnt/.DS_Store" "$out/DS_Store"
detach "$mnt"
mnt=
python3 -I "$here/clean-dsstore.py" "$out/DS_Store"
# icvp holds the icon view's settings, including the background.
grep -q icvp "$out/DS_Store" || { echo "Finder didn't save the layout; run this again."; exit 1; }
echo "Saved $out/background.tiff and $out/DS_Store"
