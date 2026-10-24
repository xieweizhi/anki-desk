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

/// How large a card's text shows in the widget, relative to the card's own styling.
enum TextSize: String, CaseIterable, Identifiable {
    case small, standard, large, larger
    var id: String { rawValue }

    var zoom: Double {
        switch self {
        case .small: 0.85
        case .standard: 1
        case .large: 1.2
        case .larger: 1.4
        }
    }
}

/// Playback speeds for a card's audio, in the order the speed button steps through them.
enum AudioSpeed {
    static let all: [Double] = [0.5, 0.75, 1, 1.25, 1.5]

    static func next(after speed: Double) -> Double {
        all.first { $0 > speed } ?? all[0]
    }

    static func label(_ speed: Double) -> String {
        "\(speed.formatted(.number.precision(.fractionLength(0...2))))×"
    }
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
    var audioSpeed: Double { didSet { store.set(audioSpeed, forKey: "audioSpeed") } }
    var cardTextSize: TextSize { didSet { store.set(cardTextSize.rawValue, forKey: "cardTextSize") } }
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
        audioSpeed = (store.object(forKey: "audioSpeed") as? Double).flatMap { AudioSpeed.all.contains($0) ? $0 : nil } ?? 1
        cardTextSize = store.string(forKey: "cardTextSize").flatMap(TextSize.init) ?? .standard
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
