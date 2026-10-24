import Testing
@testable import AnkiDesk

@MainActor
struct CountingTests {
    let decks = [
        DeckStats(id: 1, name: "Japanese", newCount: 10, learnCount: 6, reviewCount: 74),
        DeckStats(id: 2, name: "Japanese::Core 2k", newCount: 10, learnCount: 6, reviewCount: 60),
        DeckStats(id: 3, name: "Spanish verbs", newCount: 8, learnCount: 0, reviewCount: 22),
        DeckStats(id: 4, name: "Japanese 2", newCount: 1, learnCount: 0, reviewCount: 0),
    ]

    @Test func subdeckOfSelectedParentIsNotCountedTwice() {
        let counted = Counting.counted(decks, selected: [1, 2, 3])
        #expect(counted.map(\.id) == [1, 3])
        #expect(Counting.totals(counted) == Totals(new: 18, learn: 6, review: 96))
    }

    @Test func similarNameIsNotTreatedAsSubdeck() {
        #expect(Counting.counted(decks, selected: [1, 4]).map(\.id) == [1, 4])
    }

    @Test func subdeckAloneIsCounted() {
        #expect(Counting.counted(decks, selected: [2]).map(\.id) == [2])
    }

    @Test func reviewWithoutAPickedDeckTakesTheCountedDecks() {
        #expect(Counting.reviewed(decks, selected: [1, 2, 3], only: nil).map(\.id) == [1, 3])
    }

    @Test func reviewOfAPickedDeckTakesOnlyThatDeck() {
        #expect(Counting.reviewed(decks, selected: [1, 2, 3], only: 3).map(\.id) == [3])
        #expect(Counting.totals(Counting.reviewed(decks, selected: [1, 3], only: 3)) == Totals(new: 8, learn: 0, review: 22))
    }

    @Test func labelUsesArrows() {
        #expect(decks[1].label == "Japanese › Core 2k")
    }

    @Test func deckQueryEscapesSearchSyntax() {
        #expect(Counting.deckQuery("Japanese::Core 2k") == #""deck:Japanese::Core 2k""#)
        #expect(Counting.deckQuery(#"A "quoted"_deck*"#) == #""deck:A \"quoted\"\_deck\*""#)
    }
}
