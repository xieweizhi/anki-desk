import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(ReviewSession.self) private var review
    let theme: Theme
    @State private var cardHeight: CGFloat = 160
    @State private var backHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let message = review.error {
                Text(message).font(theme.text(13)).foregroundStyle(theme.learn)
                ThemedButton(title: "Back", theme: theme, prominent: false) { review.stop() }
            } else if review.finished {
                finished
            } else if let card = review.card {
                cardBody(card)
            } else {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16))
        .frame(width: 360, alignment: .leading)
        .widgetCard(theme)
    }

    private var header: some View {
        HStack(spacing: 4) {
            // Only the chevron goes back. The deck name is plain text, so dragging the window by it
            // doesn't end in a click.
            Button { review.stop() } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .frame(width: 26, height: 26)
                    .background(theme.track.opacity(backHovered ? 1 : 0), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { backHovered = $0 }
            .keyboardShortcut(.cancelAction)
            .help("Back (Esc)")
            .accessibilityLabel("Back to today")
            Text(review.card?.info.deckName.replacingOccurrences(of: "::", with: " › ") ?? "Today")
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text("\(model.totals.all) left").monospacedDigit()
        }
        .font(theme.text(12))
        .foregroundStyle(theme.muted)
        .padding(.leading, -7)
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "checkmark.circle").font(.system(size: 34, weight: .light)).foregroundStyle(theme.review)
            Text("Done for now").font(theme.number(30))
            Text(model.totals.learn > 0 ? "Learning cards come back in a few minutes." : "Nothing left today in your selected decks.")
                .font(theme.text(12)).foregroundStyle(theme.muted)
            ThemedButton(title: "Back", theme: theme) { review.stop() }.padding(.top, 4)
        }
    }

    @ViewBuilder private func cardBody(_ card: ReviewSession.Card) -> some View {
        CardWebView(html: review.html, mediaDirectory: review.mediaDirectory, theme: theme, height: $cardHeight) { side, index in
            review.play(side: side, index: index)
        }
        .frame(height: cardHeight)
        .background(theme.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        if !review.soundURLs.isEmpty { audioRow }

        if review.videoCount > 0 {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                Text(review.videoCount == 1 ? "1 video can't play here." : "\(review.videoCount) videos can't play here.")
                Spacer(minLength: 0)
                Button("Open in Anki") { review.openInAnki() }.buttonStyle(.plain).fontWeight(.semibold)
            }
            .font(theme.text(12))
            .foregroundStyle(theme.learn)
            .padding(10)
            .background(theme.learn.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }

        if review.side == .question {
            Button { review.showAnswer() } label: {
                HStack(spacing: 8) {
                    Text("Show answer").font(theme.text(14, weight: .semibold))
                    Text("Space").font(theme.text(11, weight: .medium)).padding(.horizontal, 6).frame(height: 20)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.secondary.opacity(0.5)))
                        .opacity(0.75)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(theme.isDark ? Color.black : theme.background)
                .background(theme.foreground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
        } else {
            HStack(spacing: 6) {
                ease(1, "Again", theme.learn, card)
                ease(2, "Hard", theme.foreground, card)
                ease(3, "Good", theme.review, card)
                ease(4, "Easy", theme.new, card)
            }
            .disabled(review.loading)
        }
    }

    private var audioRow: some View {
        HStack(spacing: 12) {
            Button { review.audio.isPlaying ? review.audio.stop() : review.replay() } label: {
                Image(systemName: review.audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.isDark ? Color.black : theme.background)
                    .frame(width: 32, height: 32)
                    .background(theme.foreground, in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: [])
            .accessibilityLabel(review.audio.isPlaying ? "Pause audio" : "Play audio")
            Waveform(progress: review.audio.progress, lit: theme.new, dim: theme.muted.opacity(0.45))
            Text(review.duration ?? "").font(theme.text(11)).foregroundStyle(theme.muted).monospacedDigit()
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .frame(height: 44)
        .background(theme.track, in: Capsule())
    }

    private func ease(_ n: Int, _ label: String, _ color: Color, _ card: ReviewSession.Card) -> some View {
        // Anki wraps the numbers in invisible direction marks (U+2068, U+2069).
        let next = card.info.nextReviews
            .flatMap { $0.indices.contains(n - 1) ? $0[n - 1] : nil }
            .map { $0.filter { $0 != "\u{2068}" && $0 != "\u{2069}" } }
        return Button { Task { await review.answer(ease: n) } } label: {
            VStack(spacing: 2) {
                Text(label).font(theme.text(13, weight: .semibold)).foregroundStyle(color)
                Text(next.map { "\(n) · \($0)" } ?? "\(n)").font(theme.text(11)).foregroundStyle(theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(theme.track, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(String(n))), modifiers: [])
    }
}

/// A fixed bar pattern that lights up as the audio plays.
struct Waveform: View {
    let progress: Double
    let lit: Color
    let dim: Color
    private static let heights: [CGFloat] = [6, 10, 16, 22, 14, 8, 12, 20, 24, 18, 10, 6, 9, 15, 21, 17, 11, 7, 5, 9, 13, 8, 6, 4]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Self.heights.indices, id: \.self) { i in
                Capsule()
                    .fill(Double(i) / Double(Self.heights.count) < progress ? lit : dim)
                    .frame(width: 3, height: Self.heights[i])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}
