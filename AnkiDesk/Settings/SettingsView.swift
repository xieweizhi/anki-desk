import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    var openHowTo: () -> Void = {}
    @State private var openAtLogin = false

    var body: some View {
        @Bindable var prefs = model.prefs
        Form {
            Section {
                if model.decks.isEmpty {
                    Text(model.connection == .unreachable ? "Open Anki to load your decks." : "Loading decks…")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.decks) { deck in
                    Toggle(isOn: selection(deck.id)) {
                        HStack {
                            Text(deck.name.components(separatedBy: "::").last ?? deck.name)
                                .padding(.leading, CGFloat(deck.name.components(separatedBy: "::").count - 1) * 14)
                            Spacer()
                            Text("\(deck.due) due").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    .toggleStyle(.switch)
                }
            } header: {
                HStack {
                    Text("Decks to count")
                    Spacer()
                    Button("Show all") { prefs.selectedDecks = Set(model.decks.map(\.id)) }
                        .buttonStyle(.link)
                        .disabled(model.decks.isEmpty)
                }
            }

            Section("Sync") {
                Toggle("Sync with AnkiWeb automatically", isOn: $prefs.autoSync)
                Picker("Every", selection: $prefs.syncMinutes) {
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("1 hr").tag(60)
                }
                .pickerStyle(.segmented)
                .disabled(!prefs.autoSync)
                LabeledContent {
                    Button("Sync now") { Task { await model.syncNow() } }
                        .disabled(model.sync == .syncing || model.connection != .connected)
                } label: {
                    Text(syncText).foregroundStyle(.secondary)
                }
            }

            Section("Theme") {
                HStack(spacing: 10) {
                    ForEach(ThemeID.allCases) { id in
                        ThemeSwatch(id: id, selected: prefs.theme == id) { prefs.theme = id }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("Size", selection: $prefs.size) {
                    Text("Small").tag(WidgetSize.small)
                    Text("Medium").tag(WidgetSize.medium)
                    Text("Pill").tag(WidgetSize.pill)
                }
                .pickerStyle(.segmented)
                Picker("Level", selection: $prefs.level) {
                    Text("Always on top").tag(WindowLevel.onTop)
                    Text("Normal").tag(WindowLevel.normal)
                    Text("On desktop").tag(WindowLevel.desktop)
                }
                .pickerStyle(.segmented)
                Toggle("Show count in menu bar", isOn: $prefs.showCountInMenuBar)
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, on in
                        prefs.openAtLogin = on
                        openAtLogin = prefs.openAtLogin
                    }
                Toggle("Play audio automatically", isOn: $prefs.autoplayAudio)
                Toggle("Click-through (ignore the mouse)", isOn: $prefs.clickThrough)
            } header: {
                Text("Widget")
            } footer: {
                Text("With click-through on, use the shortcut to reach the widget.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                KeyboardShortcuts.Recorder("Show or hide the widget", name: .toggleWidget)
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Works from any app. In the widget, Anki's keys apply: Space shows the answer, 1–4 grade, R replays audio, Esc goes back.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Button("How to use Anki Desk…", action: openHowTo).buttonStyle(.link)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 720)
        .onAppear { openAtLogin = prefs.openAtLogin }
    }

    private var syncText: String {
        switch model.sync {
        case .idle: "Not synced yet"
        case .syncing: "Syncing…"
        case .synced(let date): "Last synced at \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message): message
        }
    }

    private func selection(_ id: Int64) -> Binding<Bool> {
        Binding {
            model.prefs.selectedDecks.contains(id)
        } set: { on in
            if on { model.prefs.selectedDecks.insert(id) } else { model.prefs.selectedDecks.remove(id) }
        }
    }
}

private struct ThemeSwatch: View {
    let id: ThemeID
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let theme = Theme.of(id)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(theme.new).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(theme.learn).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(theme.review).frame(width: 10, height: 10)
                }
                .padding(6)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottomLeading)
                .background(theme.background.opacity(1), in: RoundedRectangle(cornerRadius: 6))
                Text(id.title).font(.system(size: 12)).padding(.horizontal, 2)
            }
            .padding(6)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
