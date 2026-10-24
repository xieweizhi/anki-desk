import AppKit
import SwiftUI
import Testing
@testable import AnkiDesk

/// Renders the README image from the real widget views.
/// Run with TEST_RUNNER_ANKIDESK_HERO_PATH=/path/to/screenshot.png.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANKIDESK_HERO_PATH"] != nil))
struct HeroImageTests {
    static let decks = [
        DeckStats(id: 1, name: "Japanese::Core 2k", newCount: 10, learnCount: 6, reviewCount: 74),
        DeckStats(id: 2, name: "Medicine::Pharmacology", newCount: 0, learnCount: 3, reviewCount: 41),
        DeckStats(id: 3, name: "Spanish verbs", newCount: 8, learnCount: 0, reviewCount: 22),
        DeckStats(id: 4, name: "Archive", newCount: 0, learnCount: 0, reviewCount: 12),
        DeckStats(id: 5, name: "Default", newCount: 0, learnCount: 0, reviewCount: 0),
    ]

    static func widget(_ theme: ThemeID, _ size: WidgetSize) -> some View {
        let prefs = Preferences(store: .testStore())
        prefs.theme = theme
        prefs.size = size
        prefs.selectedDecks = [1, 2, 3]
        let model = AppModel(prefs: prefs)
        model.apply(decks: decks)
        return WidgetRootView()
            .environment(model)
            .environment(ReviewSession(model: model))
            .shadow(color: Color(hex: 0x0A0E16, opacity: 0.35), radius: 24, y: 14)
    }

    @Test func hero() throws {
        let view = ZStack(alignment: .topLeading) {
            // A quiet dusk desktop.
            Color(hex: 0x9DB0C2)
            Ellipse().fill(Color(hex: 0x6F8499)).frame(width: 1800, height: 700).offset(x: -260, y: 470)
            Ellipse().fill(Color(hex: 0x53687E)).frame(width: 1400, height: 700).offset(x: 420, y: 560)
            Ellipse().fill(Color(hex: 0x3D4F63)).frame(width: 1300, height: 700).offset(x: -420, y: 620)

            VStack(alignment: .leading, spacing: 18) {
                Text("Anki Desk").font(.system(size: 60, weight: .bold))
                Text("Today's Anki cards, right on your Mac desktop.")
                    .font(.system(size: 24, weight: .medium))
                    .opacity(0.92)
                VStack(alignment: .leading, spacing: 10) {
                    feature("rectangle.stack", "Cards left today, per deck")
                    feature("play.rectangle", "Review in place, with images and audio")
                    feature("arrow.triangle.2.circlepath", "Syncs with AnkiWeb on its own")
                    feature("keyboard", "⌃⌥A from any app")
                    feature("paintpalette", "4 themes · 3 sizes · always on top or on the desktop")
                }
                .padding(.top, 14)
            }
            .foregroundStyle(.white)
            .frame(width: 520, alignment: .leading)
            .offset(x: 72, y: 150)

            Self.widget(.midnight, .medium).offset(x: 640, y: 118)
            Self.widget(.paper, .small).offset(x: 968, y: 118)
            Self.widget(.terminal, .small).offset(x: 968, y: 314)
            Self.widget(.matcha, .pill).offset(x: 640, y: 482)
        }
        .frame(width: 1280, height: 720, alignment: .topLeading)
        .clipped()
        .environment(\.widgetBlur, false)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        let rep = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: ProcessInfo.processInfo.environment["ANKIDESK_HERO_PATH"]!))
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).frame(width: 24)
            Text(text).font(.system(size: 18))
        }
    }
}
