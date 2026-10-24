import Foundation

struct DeckStats: Codable, Hashable, Identifiable {
    let id: Int64
    let name: String
    var newCount: Int
    var learnCount: Int
    var reviewCount: Int

    var due: Int { newCount + learnCount + reviewCount }
    /// "Japanese::Core 2k" reads as "Japanese › Core 2k".
    var label: String { name.replacingOccurrences(of: "::", with: " › ") }
}

struct Totals: Equatable {
    var new = 0
    var learn = 0
    var review = 0
    var all: Int { new + learn + review }
}

enum Counting {
    /// The selected decks to show and add up. A selected subdeck whose parent is also
    /// selected is dropped: the parent's counts already include it.
    static func counted(_ decks: [DeckStats], selected: Set<Int64>) -> [DeckStats] {
        let chosen = decks.filter { selected.contains($0.id) }
        let names = Set(chosen.map(\.name))
        return chosen.filter { deck in !names.contains { deck.name.hasPrefix($0 + "::") } }
    }

    /// The decks a review takes cards from: one deck when the user picked it, else the counted ones.
    static func reviewed(_ decks: [DeckStats], selected: Set<Int64>, only deck: Int64?) -> [DeckStats] {
        guard let deck else { return counted(decks, selected: selected) }
        return decks.filter { $0.id == deck }
    }

    static func totals(_ decks: [DeckStats]) -> Totals {
        decks.reduce(into: Totals()) {
            $0.new += $1.newCount
            $0.learn += $1.learnCount
            $0.review += $1.reviewCount
        }
    }

    /// A search term that matches one deck and its subdecks, escaped for Anki's search syntax.
    static func deckQuery(_ name: String) -> String {
        var escaped = ""
        for ch in name {
            if "\\\"*_".contains(ch) { escaped.append("\\") }
            escaped.append(ch)
        }
        return "\"deck:\(escaped)\""
    }
}
