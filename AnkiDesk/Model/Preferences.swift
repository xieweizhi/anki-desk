import Foundation
import Observation
import ServiceManagement
import KeyboardShortcuts

enum ThemeID: String, CaseIterable, Identifiable {
    case paper, midnight, matcha, terminal
    var id: String { rawValue }
}

enum WidgetSize: String, CaseIterable, Identifiable {
    case small, medium, pill
    var id: String { rawValue }
}

enum WindowLevel: String, CaseIterable, Identifiable {
    case onTop, normal, desktop
    var id: String { rawValue }
}

extension KeyboardShortcuts.Name {
    static let toggleWidget = Self("toggleWidget", default: .init(.a, modifiers: [.control, .option]))
}

/// User choices, stored in UserDefaults.
@Observable
final class Preferences {
    private let store: UserDefaults

    var theme: ThemeID { didSet { store.set(theme.rawValue, forKey: "theme") } }
    var size: WidgetSize { didSet { store.set(size.rawValue, forKey: "size") } }
    var level: WindowLevel { didSet { store.set(level.rawValue, forKey: "level") } }
    var autoSync: Bool { didSet { store.set(autoSync, forKey: "autoSync") } }
    var syncMinutes: Int { didSet { store.set(syncMinutes, forKey: "syncMinutes") } }
    var selectedDecks: Set<Int64> { didSet { store.set(selectedDecks.map { NSNumber(value: $0) }, forKey: "selectedDecks") } }
    var showCountInMenuBar: Bool { didSet { store.set(showCountInMenuBar, forKey: "showCountInMenuBar") } }
    var clickThrough: Bool { didSet { store.set(clickThrough, forKey: "clickThrough") } }
    var autoplayAudio: Bool { didSet { store.set(autoplayAudio, forKey: "autoplayAudio") } }
    var finishedSetup: Bool { didSet { store.set(finishedSetup, forKey: "finishedSetup") } }
    var openAnkiOnStart: Bool { didSet { store.set(openAnkiOnStart, forKey: "openAnkiOnStart") } }

    init(store: UserDefaults = .standard) {
        self.store = store
        theme = store.string(forKey: "theme").flatMap(ThemeID.init) ?? .midnight
        size = store.string(forKey: "size").flatMap(WidgetSize.init) ?? .medium
        level = store.string(forKey: "level").flatMap(WindowLevel.init) ?? .onTop
        autoSync = store.object(forKey: "autoSync") as? Bool ?? true
        syncMinutes = store.object(forKey: "syncMinutes") as? Int ?? 15
        selectedDecks = Set((store.array(forKey: "selectedDecks") as? [NSNumber] ?? []).map(\.int64Value))
        showCountInMenuBar = store.object(forKey: "showCountInMenuBar") as? Bool ?? true
        clickThrough = store.bool(forKey: "clickThrough")
        autoplayAudio = store.object(forKey: "autoplayAudio") as? Bool ?? true
        finishedSetup = store.bool(forKey: "finishedSetup")
        openAnkiOnStart = store.object(forKey: "openAnkiOnStart") as? Bool ?? true
    }

    var openAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Anki Desk: open at login failed: \(error)")
            }
        }
    }
}
