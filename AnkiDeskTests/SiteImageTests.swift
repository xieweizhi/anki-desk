import AppKit
import SwiftUI
import Testing
@testable import AnkiDesk

/// Renders the landing page's widget images from the real widget views, on a transparent background.
/// Run with TEST_RUNNER_ANKIDESK_SITE_DIR=$PWD/site/public/img.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANKIDESK_SITE_DIR"] != nil))
struct SiteImageTests {
    @Test(arguments: [
        (ThemeID.paper, WidgetSize.medium), (.midnight, .medium), (.matcha, .medium), (.terminal, .medium),
        (.paper, .small), (.midnight, .small), (.matcha, .small), (.terminal, .small),
        (.paper, .pill), (.midnight, .pill), (.matcha, .pill), (.terminal, .pill),
    ])
    func widget(_ theme: ThemeID, _ size: WidgetSize) throws {
        let view = HeroImageTests.widget(theme, size)
            .padding(EdgeInsets(top: 16, leading: 40, bottom: 56, trailing: 40))
            .environment(\.widgetBlur, false)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        let rep = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try #require(rep.representation(using: .png, properties: [:]))
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ANKIDESK_SITE_DIR"]!)
        try png.write(to: dir.appendingPathComponent("widget-\(theme.rawValue)-\(size.rawValue).png"))
    }
}
