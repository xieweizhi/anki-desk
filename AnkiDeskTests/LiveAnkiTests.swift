import Foundation
import Testing
@testable import AnkiDesk

/// Read-only checks against a running Anki with AnkiConnect. Never answers or syncs.
/// Run with TEST_RUNNER_ANKIDESK_LIVE=1.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["ANKIDESK_LIVE"] == "1"))
struct LiveAnkiTests {
    @Test func countsAndFirstCardLoad() async throws {
        let prefs = Preferences(store: .testStore())
        let model = AppModel(prefs: prefs)
        await model.refresh()
        #expect(model.connection == .connected)
        let busiest = try #require(model.decks.filter { !$0.name.contains("::") }.max { $0.due < $1.due })
        prefs.selectedDecks = [busiest.id]
        print("LIVE decks=\(model.decks.count) busiest=\(busiest.name) due=\(busiest.due) totals=\(model.totals)")

        let review = ReviewSession(model: model)
        prefs.autoplayAudio = false
        await review.start()
        #expect(review.error == nil)
        if busiest.due == 0 {
            #expect(review.finished)
            return
        }
        let card = try #require(review.card)
        let dir = try #require(review.mediaDirectory)
        #expect(FileManager.default.fileExists(atPath: dir.path))
        #expect(!review.html.contains("[anki:play"))
        let qMarkers = CardMedia.playRefs(in: card.info.question).count
        print("LIVE card=\(card.info.cardId) model=\(card.info.modelName) qMarkers=\(qMarkers) qTags=\(card.question) aTags=\(card.answer) next=\(card.info.nextReviews ?? [])")
        #expect(qMarkers <= card.question.count)
        for url in review.soundURLs {
            #expect(FileManager.default.fileExists(atPath: url.path), "missing \(url.lastPathComponent)")
        }
        review.showAnswer()
        #expect(review.side == .answer)
        print("LIVE answer sounds=\(review.soundURLs.map(\.lastPathComponent)) videos=\(review.videoCount)")
        review.stop()
    }

    @Test func audioTagsMatchAnkisMarkers() async throws {
        let anki = AnkiConnect()
        let ids = try await anki.findCards("*sound:*").prefix(20)
        try #require(!ids.isEmpty, "no cards with audio in this collection")
        let dir = try await anki.mediaDirectory()
        for info in try await anki.cardsInfo(Array(ids)) {
            let type = try await anki.noteType(named: info.modelName)
            let template = try #require(type.tmpls.first { $0.ord == info.ord })
            let tags = CardMedia.resolve(card: info, template: template)
            let q = (CardMedia.playRefs(in: info.question).map(\.index).max() ?? -1) + 1
            let a = (CardMedia.playRefs(in: info.answer).filter { $0.side == "a" }.map(\.index).max() ?? -1) + 1
            #expect(tags.question.count == q, "card \(info.cardId) question: \(tags.question) vs \(q) markers")
            #expect(tags.answer.count == a, "card \(info.cardId) answer: \(tags.answer) vs \(a) markers")
            for case .sound(let file) in tags.question + tags.answer {
                #expect(FileManager.default.fileExists(atPath: dir.appending(path: file).path), "missing \(file)")
            }
        }
        print("LIVE checked \(ids.count) audio cards")
    }
}
