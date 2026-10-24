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

    @Test func audioPlaysAtNormalSpeedAtFirst() {
        #expect(Preferences(store: .testStore()).audioSpeed == 1)
    }

    @Test func remembersAudioSpeed() {
        let store = UserDefaults.testStore()
        Preferences(store: store).audioSpeed = 0.75
        #expect(Preferences(store: store).audioSpeed == 0.75)
    }

    @Test func speedButtonStepsThroughEachSpeedAndWraps() {
        var speed = 1.0
        var seen: [Double] = []
        for _ in AudioSpeed.all {
            speed = AudioSpeed.next(after: speed)
            seen.append(speed)
        }
        #expect(seen == [1.25, 1.5, 0.5, 0.75, 1])
        #expect(AudioSpeed.all.map(AudioSpeed.label) == ["0.5×", "0.75×", "1×", "1.25×", "1.5×"])
    }

    @Test func cardTextIsDefaultSizeAtFirst() {
        #expect(Preferences(store: .testStore()).cardTextSize == .standard)
    }

    @Test func remembersCardTextSize() {
        let store = UserDefaults.testStore()
        Preferences(store: store).cardTextSize = .larger
        #expect(Preferences(store: store).cardTextSize == .larger)
    }
}
