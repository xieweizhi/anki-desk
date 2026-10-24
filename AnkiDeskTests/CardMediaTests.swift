import Testing
@testable import AnkiDesk

@MainActor
struct CardMediaTests {
    let fields = [
        "Word": "猫 [sound:neko.mp3]",
        "Picture": #"<img src="cat.jpg">"#,
        "Meaning": "cat [sound:cat-en.mp3][sound:clip.mp4]",
    ]

    func card(question: String, answer: String) -> CardInfo {
        CardInfo(cardId: 1, question: question, answer: answer, deckName: "Japanese", modelName: "Basic", ord: 0, css: "",
                 fields: fields.mapValues { CardInfo.Field(value: $0, order: 0) }, nextReviews: nil)
    }

    @Test func soundFilesInOrder() {
        #expect(CardMedia.soundFiles(in: "a [sound:1.mp3] b [sound:two words.ogg]") == ["1.mp3", "two words.ogg"])
    }

    @Test func templateTagsFollowFieldReferences() {
        let tags = CardMedia.tags(template: "{{Picture}}<br>{{Word}}{{#Meaning}}{{text:Meaning}}{{/Meaning}}", fields: fields)
        #expect(tags == [.sound("neko.mp3"), .sound("cat-en.mp3"), .sound("clip.mp4")])
    }

    @Test func ttsAndLiteralSoundsCount() {
        let tags = CardMedia.tags(template: "{{tts en_US:Meaning}} [sound:ding.mp3] [anki:tts lang=ja_JP]猫[/anki:tts]", fields: fields)
        #expect(tags == [.tts, .sound("ding.mp3"), .tts])
    }

    @Test func typeAnswerFieldIsSkipped() {
        #expect(CardMedia.tags(template: "{{type:Word}}", fields: fields).isEmpty)
    }

    @Test func answerWithFrontSideRepeatsFrontAudioWhenMarkersSaySo() {
        let template = NoteType.Template(ord: 0, qfmt: "{{Word}}", afmt: "{{FrontSide}}<hr id=answer>{{Meaning}}")
        let withFront = card(question: "猫 [anki:play:q:0]",
                             answer: "猫 [anki:play:a:0]<hr id=answer>cat [anki:play:a:1][anki:play:a:2]")
        #expect(CardMedia.resolve(card: withFront, template: template).answer
                == [.sound("neko.mp3"), .sound("cat-en.mp3"), .sound("clip.mp4")])

        let withoutFront = card(question: "猫 [anki:play:q:0]",
                                answer: "猫 [anki:play:q:0]<hr id=answer>cat [anki:play:a:0][anki:play:a:1]")
        let resolved = CardMedia.resolve(card: withoutFront, template: template)
        #expect(resolved.question == [.sound("neko.mp3")])
        #expect(resolved.answer == [.sound("cat-en.mp3"), .sound("clip.mp4")])
    }

    @Test func playMarkersBecomeLinks() {
        let html = CardMedia.replacingPlayMarkers(in: "x [anki:play:a:12] y")
        #expect(html.contains(#"href="ankidesk-play://a/12""#))
        #expect(!html.contains("[anki:play"))
    }

    @Test func videoIsDetectedByExtension() {
        #expect(CardMedia.isVideo("clip.MP4"))
        #expect(!CardMedia.isVideo("neko.mp3"))
    }
}
