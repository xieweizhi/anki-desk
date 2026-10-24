#!/bin/bash
# Builds a universal Release app, packs it into a DMG, and (with --publish) attaches it to a GitHub release.
#   scripts/release.sh            # build/AnkiDesk.dmg only
#   scripts/release.sh --publish  # also create release v<MARKETING_VERSION> on GitHub
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
products=build/Build/Products/Release
dmg=build/AnkiDesk.dmg

xcodegen generate --quiet
xcodebuild -project AnkiDesk.xcodeproj -scheme AnkiDesk -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build -quiet build

app="$products/AnkiDesk.app"
codesign --verify --deep --strict "$app"
lipo -archs "$app/Contents/MacOS/AnkiDesk"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
# Build a writable image, fill it while it's mounted out of sight, then compress it. A one-step
# `hdiutil create -srcfolder` often can't unmount its temporary volume while Spotlight is indexing it.
rw="$stage.rw.dmg"
rm -f "$dmg" "$rw"
hdiutil create -volname "Anki Desk" -size 64m -fs HFS+ -type UDIF -layout NONE -quiet "$rw"
mount=$(hdiutil attach "$rw" -nobrowse -noautoopen | tail -1 | cut -f3)
mdutil -i off "$mount" >/dev/null 2>&1 || true
ditto "$stage" "$mount"
hdiutil detach "$mount" -force -quiet
hdiutil convert "$rw" -format UDZO -imagekey zlib-level=9 -quiet -o "$dmg"
rm -f "$rw"
echo "Built $dmg (v$version, $(du -h "$dmg" | cut -f1))"

if [[ "${1:-}" == "--publish" ]]; then
    gh release create "v$version" "$dmg" --title "Anki Desk $version" --notes-file - <<EOF
Download **AnkiDesk.dmg**, open it, and drag Anki Desk to Applications.

Anki Desk isn't notarized yet, so macOS blocks the first launch. Open it once, then go to
System Settings › Privacy & Security and click **Open Anyway**. Or run:

\`\`\`bash
xattr -dr com.apple.quarantine /Applications/AnkiDesk.app
\`\`\`

Needs macOS 14 or later, and Anki with the [AnkiConnect](https://ankiweb.net/shared/info/2055492159) add-on.
EOF
fi
