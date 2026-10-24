import AppKit
import SwiftUI
import Testing
@testable import AnkiDesk

/// Renders every theme, size and state to PNG for a visual check.
/// Set ANKIDESK_SNAPSHOT_DIR to choose where the images go; without it the test only checks that each view renders.
@MainActor
struct SnapshotTests {
    let decks = [
        DeckStats(id: 1, name: "Japanese::Core 2k", newCount: 10, learnCount: 6, reviewCount: 74),
        DeckStats(id: 2, name: "Medicine::Pharmacology", newCount: 0, learnCount: 3, reviewCount: 41),
        DeckStats(id: 3, name: "Spanish verbs", newCount: 8, learnCount: 0, reviewCount: 22),
        DeckStats(id: 4, name: "Archive", newCount: 0, learnCount: 0, reviewCount: 12),
        DeckStats(id: 5, name: "Default", newCount: 0, learnCount: 0, reviewCount: 0),
    ]

    func makeModel(theme: ThemeID, size: WidgetSize, state: WidgetState) -> AppModel {
        let prefs = Preferences(store: .testStore())
        prefs.theme = theme
        prefs.size = size
        prefs.selectedDecks = state == .noDecks ? [] : [1, 2, 3]
        let model = AppModel(prefs: prefs)
        switch state {
        case .loading: break
        case .unreachable:
            model.apply(decks: decks, at: Date(timeIntervalSince1970: 1_792_839_540))
            model.markUnreachable()
        case .done:
            model.apply(decks: decks.map { DeckStats(id: $0.id, name: $0.name, newCount: 0, learnCount: 0, reviewCount: 0) })
        case .noDecks, .counts:
            model.apply(decks: decks)
        }
        return model
    }

    func render(_ model: AppModel, name: String) throws {
        let view = WidgetRootView()
            .environment(model)
            .environment(ReviewSession(model: model))
            .padding(24)
            .background(Color(hex: 0x6F8499))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.nsImage, "\(name) did not render")
        guard let dir = ProcessInfo.processInfo.environment["ANKIDESK_SNAPSHOT_DIR"] else { return }
        let rep = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }

    @Test(arguments: ThemeID.allCases)
    func everySizeRenders(theme: ThemeID) throws {
        for size in WidgetSize.allCases {
            try render(makeModel(theme: theme, size: size, state: .counts), name: "size-\(size.rawValue)-\(theme.rawValue)")
        }
    }

    @Test func howToRenders() throws {
        try save(HowToContent().background(.white), name: "howto")
    }

    @Test func connectRenders() throws {
        let model = makeModel(theme: .paper, size: .medium, state: .counts)
        try save(ConnectView(onDone: {}).environment(model).background(.white), name: "connect")
    }

    func save(_ view: some View, name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.nsImage, "\(name) did not render")
        guard let dir = ProcessInfo.processInfo.environment["ANKIDESK_SNAPSHOT_DIR"] else { return }
        let rep = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        try #require(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }

    @Test(arguments: [WidgetState.loading, .unreachable, .noDecks, .done, .counts])
    func everyStateRenders(state: WidgetState) throws {
        try render(makeModel(theme: .paper, size: .medium, state: state), name: "state-\(state)")
    }
}
