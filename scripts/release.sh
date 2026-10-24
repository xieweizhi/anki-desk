#!/bin/bash
# Builds a universal Release app, signs it, packs it into a DMG, and (with --publish) attaches it to a GitHub release.
#   scripts/release.sh            # build/AnkiDesk.dmg only
#   scripts/release.sh --publish  # also create release v<MARKETING_VERSION> on GitHub
#
# With a "Developer ID Application" certificate in the keychain, the app and DMG are signed with it, notarized
# and stapled, so they open without a Gatekeeper warning. Without one, the app is signed ad hoc.
#   DEVELOPER_ID    signing identity (default: the first "Developer ID Application" identity in the keychain)
#   NOTARY_PROFILE  notarytool keychain profile (default: anki-desk), made once with `xcrun notarytool store-credentials`
#   NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD
#                   notarize with these instead of a keychain profile (used by .github/workflows/release.yml)
#   RELEASE_TAG     the tag being released; must be v<MARKETING_VERSION>. An annotated tag's message becomes
#                   the release notes' list of changes.
# On CI (CI is set) a missing Developer ID is an error rather than an ad hoc build.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
products=build/Build/Products/Release
dmg=build/AnkiDesk.dmg
identity=${DEVELOPER_ID:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)}

if [[ -n "${NOTARY_PASSWORD:-}" ]]; then
    notary=(--apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_PASSWORD")
else
    notary=(--keychain-profile "${NOTARY_PROFILE:-anki-desk}")
fi

if [[ -n "${RELEASE_TAG:-}" && "$RELEASE_TAG" != "v$version" ]]; then
    echo "Tag $RELEASE_TAG doesn't match MARKETING_VERSION $version in project.yml." >&2
    exit 1
fi

if [[ -n "$identity" ]]; then
    xcrun notarytool history "${notary[@]}" >/dev/null 2>&1 || {
        echo "Can't reach the notary service with these credentials. For a keychain profile, create it once with:" >&2
        echo "  xcrun notarytool store-credentials anki-desk --apple-id <apple id> --team-id <team id>" >&2
        exit 1
    }
    echo "Signing with $identity"
elif [[ -n "${CI:-}" ]]; then
    echo "No Developer ID Application certificate in the keychain." >&2
    exit 1
else
    echo "No Developer ID Application certificate: signing ad hoc, not notarizing."
fi

xcodegen generate --quiet
xcodebuild -project AnkiDesk.xcodeproj -scheme AnkiDesk -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build -quiet build

app="$products/AnkiDesk.app"
# The hardened runtime is required for notarization; the app needs no entitlements under it.
if [[ -n "$identity" ]]; then
    codesign --force --options runtime --timestamp --sign "$identity" "$app"
else
    codesign --force --options runtime --sign - "$app"
fi
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

if [[ -n "$identity" ]]; then
    codesign --sign "$identity" --timestamp "$dmg"
    # Notarizing the DMG also notarizes the app inside it; stapling lets it open offline.
    xcrun notarytool submit "$dmg" "${notary[@]}" --wait
    xcrun stapler staple "$dmg"
    spctl --assess --type open --context context:primary-signature --verbose "$dmg"
fi
echo "Built $dmg (v$version, $(du -h "$dmg" | cut -f1))"

if [[ "${1:-}" == "--publish" ]]; then
    if [[ -n "$identity" ]]; then
        first_launch=""
    else
        first_launch="
Anki Desk isn't notarized, so macOS blocks the first launch. Open it once, then go to
System Settings › Privacy & Security and click **Open Anyway**.
"
    fi
    # An annotated tag's message lists what changed (git tag -a v1.2.3 -m "- Fixes ..."). A lightweight tag adds nothing.
    changes=""
    if [[ "$(git cat-file -t "v$version" 2>/dev/null)" == "tag" ]]; then
        changes="$(git tag -l --format='%(contents)' "v$version" | sed '/^-----BEGIN PGP SIGNATURE-----/,$d')

"
    fi
    gh release create "v$version" "$dmg" --title "Anki Desk $version" --notes-file - <<EOF
${changes}Download **AnkiDesk.dmg**, open it, and drag Anki Desk to Applications.
$first_launch
Needs macOS 14 or later, and Anki with the [AnkiConnect](https://ankiweb.net/shared/info/2055492159) add-on.
EOF
fi
