import SwiftUI

/// First run: get AnkiConnect installed and Anki open. There is no account of our own.
struct ConnectView: View {
    @Environment(AppModel.self) private var model
    let onDone: () -> Void
    @State private var copied = false

    static let addonCode = "2055492159"

    var body: some View {
        let connected = model.connection == .connected
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Connect to Anki").font(.system(size: 22, weight: .semibold))
                Text("Anki Desk reads your decks from the Anki app on this Mac. There is no separate account.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 10) {
                step(1, "Install AnkiConnect", done: connected,
                     status: connected ? "Installed" : "Not found",
                     body: "In Anki: Tools › Add-ons › Get Add-ons, paste this code, then restart Anki.") {
                    HStack(spacing: 8) {
                        Text(Self.addonCode).font(.system(size: 13, design: .monospaced)).textSelection(.enabled)
                            .padding(.horizontal, 10).frame(height: 28)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                        Button(copied ? "Copied" : "Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(Self.addonCode, forType: .string)
                            copied = true
                        }
                    }
                }
                step(2, "Open Anki", done: connected || model.ankiRunning,
                     status: connected ? "Running\(model.profile.map { " · profile \"\($0)\"" } ?? "")" : model.ankiRunning ? "Running" : "Waiting for Anki…",
                     body: "Keep Anki running in the background. Anki Desk checks it every few seconds.") {
                    if !model.ankiRunning && !connected { Button("Open Anki") { model.openAnki() } }
                }
                step(3, "Sign in to AnkiWeb (optional)", done: isSynced, status: syncStatus,
                     body: "Click Sync once in Anki and sign in. Anki Desk syncs through Anki and never sees your password.") {
                    if connected && !isSynced { Button("Test sync") { Task { await model.syncNow() } }.disabled(model.sync == .syncing) }
                }
            }
            HStack {
                Button("Check again") { Task { await model.refresh() } }
                Spacer()
                Button("Choose decks") {
                    model.prefs.finishedSetup = true
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!connected)
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 480)
    }

    private var isSynced: Bool {
        if case .synced = model.sync { true } else { false }
    }

    private var syncStatus: String {
        switch model.sync {
        case .synced: "Sync works"
        case .syncing: "Syncing…"
        case .failed(let message): message
        case .idle: "Optional"
        }
    }

    private func step(_ n: Int, _ title: String, done: Bool, status: String, body: String,
                      @ViewBuilder extra: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(done ? Color.green : Color.secondary.opacity(0.2)).frame(width: 24, height: 24)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(n)").font(.system(size: 12, weight: .semibold))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(status).font(.system(size: 12)).foregroundStyle(done ? Color.green : .secondary)
                }
                Text(body).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                extra()
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }
}
