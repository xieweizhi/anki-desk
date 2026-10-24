import Foundation

enum AnkiError: Error, Equatable {
    /// Nothing answers on the AnkiConnect port: Anki is closed or the add-on is missing.
    case unreachable
    /// AnkiConnect answered with an error message.
    case api(String)
    case badResponse
}

/// Client for the AnkiConnect add-on (https://git.foosoft.net/alex/anki-connect), API version 6.
struct AnkiConnect {
    var endpoint = URL(string: "http://127.0.0.1:8765")!

    private struct Envelope<T: Decodable>: Decodable {
        let result: T?
        let error: String?
    }

    func call<T: Decodable>(_ action: String, _ params: [String: Any] = [:], timeout: TimeInterval = 8, as type: T.Type = T.self) async throws -> T? {
        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["action": action, "version": 6]
        if !params.isEmpty { body["params"] = params }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .networkConnectionLost {
            // AnkiConnect closes idle connections; a reused one fails once. Retry on a fresh connection.
            do {
                (data, _) = try await URLSession.shared.data(for: request)
            } catch is URLError {
                throw AnkiError.unreachable
            }
        } catch let error as URLError where [.cannotConnectToHost, .cannotFindHost, .notConnectedToInternet, .timedOut].contains(error.code) {
            throw AnkiError.unreachable
        }
        guard let envelope = try? JSONDecoder().decode(Envelope<T>.self, from: data) else { throw AnkiError.badResponse }
        if let message = envelope.error { throw AnkiError.api(message) }
        return envelope.result
    }

    // MARK: Actions

    func version() async throws -> Int {
        guard let v = try await call("version", as: Int.self) else { throw AnkiError.badResponse }
        return v
    }

    func activeProfile() async throws -> String? {
        try await call("getActiveProfile", as: String.self)
    }

    /// Today's counts for every deck. Anki's counts for a deck include its subdecks.
    func allDeckStats() async throws -> [DeckStats] {
        let ids = try await call("deckNamesAndIds", as: [String: Int64].self) ?? [:]
        guard !ids.isEmpty else { return [] }
        struct Raw: Decodable {
            let deck_id: Int64, new_count: Int, learn_count: Int, review_count: Int
        }
        let raw = try await call("getDeckStats", ["decks": Array(ids.keys)], as: [String: Raw].self) ?? [:]
        let names = Dictionary(uniqueKeysWithValues: ids.map { ($1, $0) })
        return raw.values.compactMap { r in
            guard let name = names[r.deck_id] else { return nil }
            return DeckStats(id: r.deck_id, name: name, newCount: r.new_count, learnCount: r.learn_count, reviewCount: r.review_count)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Runs Anki's own AnkiWeb sync, with the login saved in Anki.
    func sync() async throws {
        _ = try await call("sync", timeout: 300, as: Bool.self)
    }

    func mediaDirectory() async throws -> URL {
        guard let path = try await call("getMediaDirPath", as: String.self) else { throw AnkiError.badResponse }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func findCards(_ query: String) async throws -> [Int64] {
        try await call("findCards", ["query": query], as: [Int64].self) ?? []
    }

    func cardsInfo(_ ids: [Int64]) async throws -> [CardInfo] {
        try await call("cardsInfo", ["cards": ids], as: [CardInfo].self) ?? []
    }

    func noteType(named name: String) async throws -> NoteType {
        guard let model = try await call("findModelsByName", ["modelNames": [name]], as: [NoteType].self)?.first else {
            throw AnkiError.badResponse
        }
        return model
    }

    /// Grades a card with Anki's scheduler: 1 Again, 2 Hard, 3 Good, 4 Easy.
    func answer(cardID: Int64, ease: Int) async throws {
        let ok = try await call("answerCards", ["answers": [["cardId": cardID, "ease": ease]]], as: [Bool].self)
        if ok?.first != true { throw AnkiError.api("Card not found") }
    }

    func browse(cardID: Int64) async throws {
        _ = try await call("guiBrowse", ["query": "cid:\(cardID)"], as: [Int64].self)
    }
}

struct CardInfo: Decodable, Equatable {
    struct Field: Decodable, Equatable { let value: String; let order: Int }

    let cardId: Int64
    let question: String
    let answer: String
    let deckName: String
    let modelName: String
    let ord: Int
    let css: String
    let fields: [String: Field]
    let nextReviews: [String]?
}

struct NoteType: Decodable, Equatable {
    struct Template: Decodable, Equatable { let ord: Int; let qfmt: String; let afmt: String }
    let name: String
    let tmpls: [Template]
}
