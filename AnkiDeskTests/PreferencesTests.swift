import Foundation
import Testing
@testable import AnkiDesk

@MainActor
struct PreferencesTests {
    @Test func opensAnkiOnStartByDefault() {
        #expect(Preferences(store: .testStore()).openAnkiOnStart)
    }

    @Test func remembersTurningOffOpenAnkiOnStart() {
        let store = UserDefaults.testStore()
        Preferences(store: store).openAnkiOnStart = false
        #expect(!Preferences(store: store).openAnkiOnStart)
    }
}
