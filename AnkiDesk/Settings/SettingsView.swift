import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    var openHowTo: () -> Void = {}
    @State private var openAtLogin = false
    /// Decks whose subdecks are showing. Groups start collapsed.
    @State private var expanded: Set<Int64> = []

    var body: some View {
        @Bindable var prefs = model.prefs
        Form {
            Section {
                if model.decks.isEmpty {
                    Text(model.connection == .unreachable ? "Open Anki to load your decks." : "Loading decks…")
                        .foregroundStyle(.secondary)
                }
                ForEach(visibleRows(DeckNode.tree(model.decks)), id: \.node.id) { row in
                    deckRow(row.node, depth: row.depth)
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
                Picker("Card text", selection: $prefs.cardTextSize) {
                    Text("Small").tag(TextSize.small)
                    Text("Default").tag(TextSize.standard)
                    Text("Large").tag(TextSize.large)
                    Text("Larger").tag(TextSize.larger)
                }
                .pickerStyle(.segmented)
                Toggle("Show count in menu bar", isOn: $prefs.showCountInMenuBar)
                Toggle("Open Anki when Anki Desk starts", isOn: $prefs.openAnkiOnStart)
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

    /// The decks to list: each top-level deck, and the subdecks of the groups that are open.
    private func visibleRows(_ nodes: [DeckNode], depth: Int = 0) -> [(node: DeckNode, depth: Int)] {
        nodes.flatMap { node in
            [(node, depth)] + (expanded.contains(node.id) ? visibleRows(node.children, depth: depth + 1) : [])
        }
    }

    /// A deck's switch, behind an arrow that opens or closes its subdecks.
    private func deckRow(_ node: DeckNode, depth: Int) -> some View {
        let open = expanded.contains(node.id)
        return HStack(spacing: 6) {
            if node.children.isEmpty {
                Color.clear.frame(width: 14)
            } else {
                Button {
                    if open { expanded.remove(node.id) } else { expanded.insert(node.id) }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .frame(width: 14, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(open ? "Hide subdecks" : "Show subdecks")
            }
            Toggle(isOn: selection(node.id)) {
                HStack {
                    Text(node.shortName)
                    Spacer()
                    if !node.children.isEmpty && !open {
                        let picked = node.descendants.filter { model.prefs.selectedDecks.contains($0.id) }.count
                        if picked > 0 {
                            Text(picked == 1 ? "1 subdeck on" : "\(picked) subdecks on").foregroundStyle(.secondary)
                        }
                    }
                    Text("\(node.deck.due) due").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .toggleStyle(.switch)
        }
        .padding(.leading, CGFloat(depth) * 20)
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
