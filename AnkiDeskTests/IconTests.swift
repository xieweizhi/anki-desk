import AppKit
import SwiftUI
import Testing
@testable import AnkiDesk

/// Renders the 1024 px app icon: a flashcard stack whose front card is the Midnight widget.
/// Run with TEST_RUNNER_ANKIDESK_ICON_PATH=/path/to/icon-1024.png.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ANKIDESK_ICON_PATH"] != nil))
struct IconTests {
    struct Icon: View {
        var body: some View {
            ZStack {
                // macOS icon grid: an 824 pt rounded square on a 1024 pt canvas.
                RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xA9BCCD), Color(hex: 0x6F8499)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay {
                        ZStack {
                            Ellipse().fill(Color(hex: 0x53687E)).frame(width: 1100, height: 520).offset(x: 260, y: 430)
                            Ellipse().fill(Color(hex: 0x3D4F63)).frame(width: 1000, height: 520).offset(x: -300, y: 500)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
                    .frame(width: 824, height: 824)
                    .shadow(color: .black.opacity(0.28), radius: 18, y: 12)

                // The card behind: Paper.
                RoundedRectangle(cornerRadius: 64, style: .continuous)
                    .fill(Color(hex: 0xF7F4EE))
                    .frame(width: 500, height: 440)
                    .rotationEffect(.degrees(-9))
                    .offset(x: -34, y: -40)
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

                // The card in front: Midnight, with the count and the new / learning / review split.
                VStack(alignment: .leading, spacing: 0) {
                    Capsule().fill(Color(hex: 0xA3A8B4)).frame(width: 120, height: 26)
                    Spacer()
                    Text("164")
                        .font(.system(size: 200, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF2F3F5))
                        .kerning(-6)
                    Spacer()
                    HStack(spacing: 14) {
                        Capsule().fill(Color(hex: 0x7AB0FF)).frame(width: 82)
                        Capsule().fill(Color(hex: 0xFF9A6B)).frame(width: 56)
                        Capsule().fill(Color(hex: 0x62D394))
                    }
                    .frame(height: 40)
                }
                .padding(EdgeInsets(top: 58, leading: 58, bottom: 62, trailing: 58))
                .frame(width: 520, height: 470)
                .background(RoundedRectangle(cornerRadius: 66, style: .continuous).fill(Color(hex: 0x181A21)))
                .overlay(RoundedRectangle(cornerRadius: 66, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 3))
                .shadow(color: .black.opacity(0.35), radius: 26, y: 18)
                .offset(x: 30, y: 46)
            }
            .frame(width: 1024, height: 1024)
        }
    }

    @Test func icon() throws {
        let renderer = ImageRenderer(content: Icon())
        renderer.scale = 1
        let image = try #require(renderer.nsImage)
        let rep = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: ProcessInfo.processInfo.environment["ANKIDESK_ICON_PATH"]!))
    }
}
