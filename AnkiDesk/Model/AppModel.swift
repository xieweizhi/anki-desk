import AppKit
import Observation

enum Connection: Equatable {
    case unknown
    case connected
    /// AnkiConnect does not answer: Anki is closed, or the add-on is missing.
    case unreachable
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case failed(String)
}

/// Live state: deck counts from Anki, connection and sync status. Polls Anki and syncs on a timer.
@Observable
final class AppModel {
    let prefs: Preferences
    let anki = AnkiConnect()

    private(set) var decks: [DeckStats] = []
    private(set) var connection: Connection = .unknown
    private(set) var countsUpdated: Date?
    private(set) var sync: SyncStatus = .idle
    private(set) var profile: String?
    private(set) var ankiRunning = false

    private var pollTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var lastSyncAttempt: Date?

    static let ankiBundleIDs = ["net.ankiweb.launcher", "net.ankiweb.dtop"]

    init(prefs: Preferences) {
        self.prefs = prefs
        if let data = UserDefaults.standard.data(forKey: "lastDecks"),
           let cached = try? JSONDecoder().decode([DeckStats].self, from: data) {
            decks = cached
            countsUpdated = UserDefaults.standard.object(forKey: "lastDecksAt") as? Date
        }
    }

    // MARK: Derived

    var counted: [DeckStats] { Counting.counted(decks, selected: prefs.selectedDecks) }
    var totals: Totals { Counting.totals(counted) }
    var hiddenDeckCount: Int { decks.count - decks.filter { prefs.selectedDecks.contains($0.id) }.count }

    // MARK: Loop

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                await self.syncIfDue()
                try? await Task.sleep(for: .seconds(self.connection == .connected ? 30 : 5))
            }
        }
    }

    func refresh() async {
        ankiRunning = NSWorkspace.shared.runningApplications.contains { Self.ankiBundleIDs.contains($0.bundleIdentifier ?? "") }
        do {
            let stats = try await anki.allDeckStats()
            if connection != .connected {
                profile = try? await anki.activeProfile()
            }
            apply(decks: stats)
            if let data = try? JSONEncoder().encode(stats) {
                UserDefaults.standard.set(data, forKey: "lastDecks")
                UserDefaults.standard.set(countsUpdated, forKey: "lastDecksAt")
            }
        } catch {
            connection = .unreachable
            profile = nil
        }
    }

    /// Takes in fresh counts from Anki.
    func apply(decks stats: [DeckStats], at date: Date = .now) {
        decks = stats
        countsUpdated = date
        connection = .connected
    }

    /// Marks Anki as gone, keeping the last counts on screen.
    func markUnreachable() {
        connection = .unreachable
    }

    private func syncIfDue() async {
        guard prefs.autoSync, connection == .connected else { return }
        let interval = TimeInterval(prefs.syncMinutes * 60)
        if let last = lastSyncAttempt, Date.now.timeIntervalSince(last) < interval { return }
        await syncNow()
    }

    func syncNow() async {
        guard sync != .syncing else { return }
        lastSyncAttempt = .now
        sync = .syncing
        do {
            try await anki.sync()
            sync = .synced(.now)
            await refresh()
        } catch AnkiError.api(let message) where message.contains("auth not configured") {
            sync = .failed("Sign in to AnkiWeb in Anki first.")
        } catch AnkiError.unreachable {
            sync = .failed("Couldn't reach Anki.")
        } catch {
            sync = .failed("Couldn't reach AnkiWeb.")
        }
    }

    func openAnki() {
        for id in Self.ankiBundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
                return
            }
        }
    }
}
