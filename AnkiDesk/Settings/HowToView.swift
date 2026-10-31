import SwiftUI
import KeyboardShortcuts

/// A short guide to everything the widget does.
struct HowToView: View {
    var body: some View {
        ScrollView { HowToContent() }
            .frame(width: 520, height: 640)
    }
}

struct HowToContent: View {
    var body: some View {
        let shortcut = KeyboardShortcuts.getShortcut(for: .toggleWidget)?.description ?? "your shortcut"
        VStack(alignment: .leading, spacing: 18) {
            Text("How to use Anki Desk").font(.system(size: 22, weight: .semibold))
            Text("A small window that shows how many Anki cards you have left today, and lets you review them without leaving what you're doing.")
                .foregroundStyle(.secondary)

            topic("link", "Connect once",
                  "Anki Desk reads your decks from the Anki app on this Mac through the AnkiConnect add-on (code 2055492159). Keep Anki open in the background; Anki Desk opens it for you when it starts (Settings › Widget). There's no account to create.")
            topic("rectangle.stack", "Pick your decks",
                  "Open Settings from the slider button on the widget or from the menu bar icon, then switch on the decks to count. A deck's count includes its subdecks.")
            topic("hand.draw", "Move it anywhere",
                  "Drag the widget by any empty spot. It stays where you leave it, even after a restart.")
            topic("square.3.layers.3d", "Choose where it lives",
                  "Settings › Widget › Level: Always on top floats over every app, Normal behaves like any window, On desktop sits behind your windows. Click-through lets the mouse pass through it.")
            topic("keyboard", "Use the shortcut",
                  "Press \(shortcut) in any app to bring the widget forward and give it the keyboard. Press it again to hide it. Change it in Settings › Shortcut.")
            topic("play.rectangle", "Review in the widget",
                  "Click Review, or click a deck in the Medium widget to review only that deck. Space shows the answer, 1 Again, 2 Hard, 3 Good, 4 Easy, R replays audio, Esc goes back. Images and audio from your cards play here; the 1× button next to the audio changes its speed, Settings › Widget › Card text makes the card text larger or smaller, and Focus mode there dims and blurs everything else while you review; anything else opens in Anki. Grades go to Anki's own scheduler.")
            topic("arrow.triangle.2.circlepath", "Sync",
                  "Anki Desk asks Anki to sync with AnkiWeb on the interval you set (Settings › Sync), using the login saved in Anki. Sign in once in Anki by clicking Sync there.")
            topic("paintpalette", "Make it yours",
                  "Four themes (Paper, Midnight, Matcha, Terminal) and three sizes (Small, Medium, Pill). The menu bar icon can show today's count too.")

            Divider()
            Text("If something looks wrong").font(.system(size: 15, weight: .semibold))
            trouble("“Anki closed”", "Open Anki. The widget keeps showing the last count until Anki answers again.")
            trouble("Nothing after opening Anki", "Check the add-on is installed (Tools › Add-ons in Anki), then restart Anki.")
            trouble("“Sync failed”", "Sign in to AnkiWeb in Anki, or check your internet connection. Counts on this Mac stay correct.")
            trouble("The shortcut does nothing", "Another app may use the same keys. Pick a different one in Settings › Shortcut.")
        }
        .padding(28)
        .frame(width: 520, alignment: .leading)
        .font(.system(size: 13))
    }

    private func topic(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func trouble(_ symptom: String, _ fix: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(symptom).fontWeight(.medium)
            Text(fix).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
