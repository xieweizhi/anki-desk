import Foundation

/// One audio/video tag on a card side, in the order Anki numbers them.
enum AVTag: Equatable {
    case sound(String)
    /// Text-to-speech: Anki speaks it; the widget can't.
    case tts
}

/// Anki renders `[sound:x.mp3]` as `[anki:play:q:0]` markers. AnkiConnect returns the markers
/// but not the files, so this rebuilds each side's tag list from the card template and the note fields.
enum CardMedia {
    static let videoExtensions: Set<String> = ["mp4", "webm", "mov", "mkv", "avi", "ogv", "mpg", "mpeg", "m4v"]

    static func isVideo(_ file: String) -> Bool {
        videoExtensions.contains((file as NSString).pathExtension.lowercased())
    }

    static func soundFiles(in text: String) -> [String] {
        text.matches(of: /\[sound:(.+?)\]/).map { String($0.1) }
    }

    /// Tags a template produces, in order. `frontSide` stands in for `{{FrontSide}}` on the back.
    static func tags(template: String, fields: [String: String], frontSide: [AVTag] = []) -> [AVTag] {
        var out: [AVTag] = []
        for match in template.matches(of: /\{\{(.*?)\}\}|\[sound:(.+?)\]|\[anki:tts[^\]]*\]/) {
            if let file = match.2 {
                out.append(.sound(String(file)))
                continue
            }
            guard let inner = match.1?.trimmingCharacters(in: .whitespaces) else {
                out.append(.tts)
                continue
            }
            guard let first = inner.first, !"#^/!".contains(first) else { continue }
            if inner == "FrontSide" {
                out += frontSide
                continue
            }
            let parts = inner.split(separator: ":", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            let filters = parts.dropLast()
            if filters.contains(where: { $0.hasPrefix("tts") }) {
                out.append(.tts)
                continue
            }
            if filters.contains("type") { continue }
            if let value = fields[parts.last ?? ""] {
                out += soundFiles(in: value).map(AVTag.sound)
            }
        }
        return out
    }

    struct PlayRef: Equatable {
        let side: Character
        let index: Int
    }

    static func playRefs(in html: String) -> [PlayRef] {
        html.matches(of: /\[anki:play:([qa]):(\d+)\]/).compactMap { m in
            Int(m.2).map { PlayRef(side: m.1.first!, index: $0) }
        }
    }

    /// Question and answer tag lists for a card. Whether the back's `{{FrontSide}}` repeats the
    /// front's audio depends on the Anki version, so pick the reading that matches the markers.
    static func resolve(card: CardInfo, template: NoteType.Template) -> (question: [AVTag], answer: [AVTag]) {
        let fields = card.fields.mapValues(\.value)
        let question = tags(template: template.qfmt, fields: fields)
        let withFront = tags(template: template.afmt, fields: fields, frontSide: question)
        let withoutFront = tags(template: template.afmt, fields: fields)
        let answerMarkers = (playRefs(in: card.answer).map(\.index).max() ?? -1) + 1
        let answer = answerMarkers == withoutFront.count && answerMarkers != withFront.count ? withoutFront : withFront
        return (question, answer)
    }

    /// Swaps the play markers for links the widget intercepts (`ankidesk-play://q/0`).
    static func replacingPlayMarkers(in html: String) -> String {
        html.replacing(/\[anki:play:([qa]):(\d+)\]/) { m in
            """
            <a class="ad-play" href="ankidesk-play://\(m.1)/\(m.2)" aria-label="Play audio">\
            <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M7 5l12 7-12 7z"/></svg></a>
            """
        }
    }
}
