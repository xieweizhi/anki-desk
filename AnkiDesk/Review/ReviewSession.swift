import Foundation
import Observation

/// Reviews the selected decks' due cards inside the widget, answering through Anki's scheduler.
@Observable
final class ReviewSession {
    enum Side { case question, answer }

    struct Card {
        let info: CardInfo
        let question: [AVTag]
        let answer: [AVTag]
    }

    private(set) var isActive = false
    private(set) var card: Card?
    private(set) var side: Side = .question
    private(set) var loading = false
    private(set) var finished = false
    private(set) var error: String?
    private(set) var mediaDirectory: URL?
    private(set) var duration: String?
    let audio = AudioPlayer()

    private let model: AppModel
    private var queue: [Int64] = []
    private var noteTypes: [String: NoteType] = [:]

    init(model: AppModel) {
        self.model = model
        audio.rate = Float(model.prefs.audioSpeed)
    }

    // MARK: Current side

    var tags: [AVTag] {
        guard let card else { return [] }
        return side == .question ? card.question : card.answer
    }

    var soundURLs: [URL] {
        guard let dir = mediaDirectory else { return [] }
        return tags.compactMap {
            guard case .sound(let file) = $0, !CardMedia.isVideo(file) else { return nil }
            return dir.appending(path: file)
        }
    }

    var videoCount: Int {
        tags.filter { if case .sound(let file) = $0 { CardMedia.isVideo(file) } else { false } }.count
    }

    var html: String {
        guard let card else { return "" }
        return CardMedia.replacingPlayMarkers(in: side == .question ? card.info.question : card.info.answer)
    }

    // MARK: Flow

    func start() async {
        guard !isActive else { return }
        isActive = true
        finished = false
        error = nil
        loading = true
        do {
            mediaDirectory = try await model.anki.mediaDirectory()
            try await buildQueue()
            await loadNext()
        } catch {
            fail(error)
        }
        loading = false
    }

    func stop() {
        isActive = false
        audio.stop()
        card = nil
        queue = []
        Task { await model.refresh() }
    }

    func showAnswer() {
        guard card != nil, side == .question else { return }
        side = .answer
        sideChanged()
    }

    func answer(ease: Int) async {
        guard let card, side == .answer, !loading else { return }
        loading = true
        audio.stop()
        do {
            try await model.anki.answer(cardID: card.info.cardId, ease: ease)
            await model.refresh()
            await loadNext()
        } catch {
            fail(error)
        }
        loading = false
    }

    func replay() {
        audio.play(soundURLs)
    }

    /// A play link inside the card: plays that one tag.
    func play(side tagSide: Character, index: Int) {
        guard let card, let dir = mediaDirectory else { return }
        let list = tagSide == "q" ? card.question : card.answer
        guard list.indices.contains(index), case .sound(let file) = list[index], !CardMedia.isVideo(file) else { return }
        audio.play([dir.appending(path: file)])
    }

    func openInAnki() {
        guard let id = card?.info.cardId else { return }
        Task { try? await model.anki.browse(cardID: id) }
    }

    // MARK: Private

    /// Learning cards first, then reviews, then new cards up to each deck's remaining new limit.
    private func buildQueue() async throws {
        var learn: [Int64] = [], review: [Int64] = [], new: [Int64] = []
        let active = "-is:suspended -is:buried"
        // Take no more of each kind than Anki's counts, which apply the deck's daily limits. A search for
        // is:due ignores them, and would keep serving a deck that Anki shows as done for today.
        for deck in model.counted {
            let d = Counting.deckQuery(deck.name)
            if deck.learnCount > 0 {
                learn += try await model.anki.findCards("\(d) is:due is:learn \(active)").sorted().prefix(deck.learnCount)
            }
            if deck.reviewCount > 0 {
                review += try await model.anki.findCards("\(d) is:due -is:learn \(active)").shuffled().prefix(deck.reviewCount)
            }
            if deck.newCount > 0 {
                new += try await model.anki.findCards("\(d) is:new \(active)").sorted().prefix(deck.newCount)
            }
        }
        var seen = Set<Int64>()
        queue = (learn + review + new).filter { seen.insert($0).inserted }
    }

    private func loadNext() async {
        card = nil
        while true {
            if queue.isEmpty {
                // Learning cards may have come due again since the queue was built.
                try? await buildQueue()
                if queue.isEmpty {
                    finished = true
                    return
                }
            }
            let id = queue.removeFirst()
            guard let info = try? await model.anki.cardsInfo([id]).first else { continue }
            do {
                let type = try await noteType(info.modelName)
                let template = type.tmpls.first { $0.ord == info.ord } ?? type.tmpls[0]
                let tags = CardMedia.resolve(card: info, template: template)
                card = Card(info: info, question: tags.question, answer: tags.answer)
            } catch {
                card = Card(info: info, question: [], answer: [])
            }
            side = .question
            sideChanged()
            return
        }
    }

    private func noteType(_ name: String) async throws -> NoteType {
        if let cached = noteTypes[name] { return cached }
        let type = try await model.anki.noteType(named: name)
        noteTypes[name] = type
        return type
    }

    private func sideChanged() {
        audio.stop()
        duration = nil
        let urls = soundURLs
        if model.prefs.autoplayAudio { audio.play(urls) }
        Task {
            let d = await AudioPlayer.duration(of: urls)
            if urls == soundURLs { duration = d }
        }
    }

    private func fail(_ error: Error) {
        self.error = (error as? AnkiError) == .unreachable ? "Couldn't reach Anki." : "Something went wrong talking to Anki."
    }
}
