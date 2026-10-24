# Anki Desk

Today's Anki cards, right on your Mac desktop. **[anki-desk.dou-tech.workers.dev](https://anki-desk.dou-tech.workers.dev)**

![Anki Desk widgets in four themes](docs/screenshot.png)

- Cards left today for the decks you pick, split into new, learning and review
- Review in place with images and audio; grades go to Anki's own scheduler
- Click a deck to review only that deck
- Card text size (Settings › Widget) and audio speed from 0.5× to 1.5× (the button beside the audio)
- Syncs with AnkiWeb on a timer, through Anki
- Drag it anywhere; keep it on top, as a normal window, or on the desktop
- ⌃⌥A shows or hides it from any app
- 4 themes, 3 sizes, count in the menu bar

## Install

1. Download **[AnkiDesk.dmg](https://github.com/xieweizhi/anki-desk/releases/latest/download/AnkiDesk.dmg)** and drag Anki Desk to Applications (macOS 14+).
2. In Anki, install [AnkiConnect](https://ankiweb.net/shared/info/2055492159) (Tools › Add-ons › Get Add-ons, code `2055492159`) and restart Anki.

Keep Anki open in the background. There's no account: Anki Desk talks to Anki on `127.0.0.1:8765`.
The menu bar icon has Settings and a How to Use guide.

To build it yourself (Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)): `scripts/release.sh` writes `build/AnkiDesk.dmg`;
`scripts/release.sh --publish` also creates the GitHub release for the version in `project.yml`.
With a Developer ID Application certificate in the keychain, the script signs, notarizes and staples the DMG.
Notarization needs a keychain profile, made once with an [app-specific password](https://account.apple.com):
`xcrun notarytool store-credentials anki-desk --apple-id <apple id> --team-id <team id>`.

To release from GitHub instead, bump `MARKETING_VERSION` in `project.yml` and push a matching annotated tag whose message lists the changes
(`git tag -a v0.1.4 -m "- What changed" && git push origin v0.1.4`); they show on the site's release notes page.
The Release workflow builds, signs, notarizes and publishes it, using the repo secrets `DEVELOPER_ID_P12`,
`DEVELOPER_ID_P12_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID` and `NOTARY_PASSWORD`.
The website is `site/public/`, served by Cloudflare Workers Static Assets: `cd site && npx wrangler deploy`.

## License

[MIT](LICENSE)
