import SwiftUI

/// What the widget can ask the app to do.
struct WidgetActions {
    var openSettings: () -> Void = {}
    var openHowTo: () -> Void = {}
    var startReview: () -> Void = {}
}

private struct WidgetActionsKey: EnvironmentKey {
    static let defaultValue = WidgetActions()
}

extension EnvironmentValues {
    var widgetActions: WidgetActions {
        get { self[WidgetActionsKey.self] }
        set { self[WidgetActionsKey.self] = newValue }
    }
}

enum WidgetState: Equatable {
    case loading
    case unreachable
    case noDecks
    case done
    case counts
}

extension AppModel {
    var widgetState: WidgetState {
        if connection == .unknown && decks.isEmpty { return .loading }
        if connection == .unreachable { return .unreachable }
        if counted.isEmpty { return .noDecks }
        if totals.all == 0 { return .done }
        return .counts
    }
}

/// Root of the floating window: the review card while reviewing, else the counts widget at the chosen size.
struct WidgetRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(ReviewSession.self) private var review

    var body: some View {
        let theme = Theme.of(model.prefs.theme)
        Group {
            if review.isActive {
                ReviewView(theme: theme)
            } else {
                switch model.prefs.size {
                case .small: SmallWidget(theme: theme)
                case .medium: MediumWidget(theme: theme)
                case .pill: PillWidget(theme: theme)
                }
            }
        }
        .fixedSize()
    }
}

// MARK: - Status line

struct StatusLine: View {
    @Environment(AppModel.self) private var model
    let theme: Theme
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let s = status(now: context.date)
            HStack(spacing: 6) {
                if model.prefs.level == .onTop && !compact {
                    Image(systemName: "pin.fill").font(.system(size: 9)).accessibilityLabel("Always on top")
                }
                if s.spinning {
                    ProgressView().controlSize(.mini).scaleEffect(0.7).frame(width: 10, height: 10)
                } else {
                    Circle().fill(s.dot).frame(width: 6, height: 6)
                }
                if !compact { Text(s.text) }
            }
            .font(theme.text(11))
            .foregroundStyle(s.isError ? theme.learn : theme.muted)
        }
    }

    private func status(now: Date) -> (text: String, dot: Color, spinning: Bool, isError: Bool) {
        if model.connection == .unreachable { return ("Anki closed", theme.muted, false, false) }
        switch model.sync {
        case .syncing: return ("Syncing…", theme.new, true, false)
        case .failed: return ("Sync failed", theme.learn, false, true)
        case .synced(let date): return ("Synced \(Self.ago(date, now: now))", theme.review, false, false)
        case .idle:
            if let updated = model.countsUpdated { return ("Updated \(Self.ago(updated, now: now))", theme.review, false, false) }
            return ("Connecting…", theme.new, true, false)
        }
    }

    static func ago(_ date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min ago" }
        return "\(Int(seconds / 3600)) h ago"
    }
}

// MARK: - Shared pieces

struct SplitBar: View {
    let totals: Totals
    let theme: Theme
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let total = max(totals.all, 1)
            let parts = [(totals.new, theme.new), (totals.learn, theme.learn), (totals.review, theme.review)].filter { $0.0 > 0 }
            let gaps = CGFloat(max(parts.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(parts.indices, id: \.self) { i in
                    Rectangle().fill(parts[i].1)
                        .frame(width: (geo.size.width - gaps) * CGFloat(parts[i].0) / CGFloat(total))
                }
            }
        }
        .frame(height: height)
        .background(theme.track)
        .clipShape(Capsule())
    }
}

struct ThemedButton: View {
    let title: String
    let theme: Theme
    var prominent = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.text(12, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 30)
                .foregroundStyle(prominent ? (theme.isDark ? Color.black : theme.background) : theme.foreground)
                .background(prominent ? theme.foreground : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(prominent ? Color.clear : theme.line))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Medium

struct MediumWidget: View {
    @Environment(AppModel.self) private var model
    @Environment(\.widgetActions) private var actions
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today").font(theme.text(12, weight: .semibold)).foregroundStyle(theme.muted)
                Spacer()
                StatusLine(theme: theme)
            }
            content
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 12, trailing: 18))
        .frame(width: 300, alignment: .leading)
        .widgetCard(theme)
    }

    @ViewBuilder private var content: some View {
        switch model.widgetState {
        case .loading:
            Text("Connecting to Anki…").font(theme.text(13)).foregroundStyle(theme.muted)
            Capsule().fill(theme.track).frame(height: 6)
            footer
        case .unreachable:
            if !model.counted.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(model.totals.all)").font(theme.number()).monospacedDigit()
                    if let at = model.countsUpdated {
                        Text("at \(at.formatted(date: .omitted, time: .shortened))").font(theme.text(13))
                    }
                }
                .foregroundStyle(theme.muted)
            }
            Text("Counts come from Anki on this Mac. Open Anki to refresh them.")
                .font(theme.text(12)).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                ThemedButton(title: "Open Anki", theme: theme) { model.openAnki() }
                Spacer()
                settingsButton
            }
        case .noDecks:
            Image(systemName: "rectangle.stack").font(.system(size: 30, weight: .light)).foregroundStyle(theme.muted)
            VStack(alignment: .leading, spacing: 6) {
                Text("No decks selected").font(theme.text(16, weight: .semibold))
                Text("Pick the decks to count. You have \(model.decks.count) in Anki.")
                    .font(theme.text(12)).foregroundStyle(theme.muted)
            }
            ThemedButton(title: "Choose decks", theme: theme, action: actions.openSettings)
        case .done:
            Image(systemName: "checkmark.circle").font(.system(size: 34, weight: .light)).foregroundStyle(theme.review)
            VStack(alignment: .leading, spacing: 6) {
                Text("All caught up").font(theme.number(32))
                Text("Nothing left today in your selected decks.").font(theme.text(12)).foregroundStyle(theme.muted)
            }
            footer
        case .counts:
            counts
        }
    }

    @ViewBuilder private var counts: some View {
        let totals = model.totals
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(totals.all)").font(theme.number()).monospacedDigit().lineLimit(1)
            Text("cards left").font(theme.text(13)).foregroundStyle(theme.muted)
        }
        VStack(alignment: .leading, spacing: 10) {
            SplitBar(totals: totals, theme: theme)
            HStack(spacing: 14) {
                legend(totals.new, "new", theme.new)
                legend(totals.learn, "learning", theme.learn)
                legend(totals.review, "review", theme.review)
            }
        }
        if case .failed(let message) = model.sync {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                Text(message).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Retry") { Task { await model.syncNow() } }.buttonStyle(.plain).fontWeight(.semibold)
            }
            .font(theme.text(12))
            .foregroundStyle(theme.learn)
            .padding(10)
            .background(theme.learn.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
        Rectangle().fill(theme.line).frame(height: 1)
        VStack(spacing: 0) {
            ForEach(model.counted) { deck in
                HStack(spacing: 6) {
                    Text(deck.label).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 4)
                    count(deck.newCount, theme.new, width: 28)
                    count(deck.learnCount, theme.learn, width: 28)
                    count(deck.reviewCount, theme.review, width: 34)
                }
                .font(theme.text(13))
                .frame(height: 28)
            }
        }
        footer
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text(model.hiddenDeckCount == 0 ? "All decks shown" : model.hiddenDeckCount == 1 ? "1 deck hidden" : "\(model.hiddenDeckCount) decks hidden")
                .font(theme.text(11)).foregroundStyle(theme.muted)
            Spacer()
            if model.totals.all > 0 && model.connection == .connected {
                ThemedButton(title: "Review", theme: theme, action: actions.startReview)
            }
            settingsButton
        }
    }

    private var settingsButton: some View {
        Button(action: actions.openSettings) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13))
                .foregroundStyle(theme.muted)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .contextMenu {
            Button("Settings…", action: actions.openSettings)
            Button("How to Use", action: actions.openHowTo)
        }
    }

    private func legend(_ n: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text("\(n)").fontWeight(.semibold).foregroundStyle(theme.foreground)
            Text(label)
        }
        .font(theme.text(12))
        .foregroundStyle(theme.muted)
        .monospacedDigit()
    }

    private func count(_ n: Int, _ color: Color, width: CGFloat) -> some View {
        Text("\(n)").monospacedDigit().foregroundStyle(n == 0 ? theme.muted : color).frame(width: width, alignment: .trailing)
    }
}

// MARK: - Small

struct SmallWidget: View {
    @Environment(AppModel.self) private var model
    @Environment(\.widgetActions) private var actions
    let theme: Theme

    var body: some View {
        let totals = model.totals
        let state = model.widgetState
        VStack(alignment: .leading) {
            HStack {
                Text("Today").font(theme.text(12, weight: .semibold)).foregroundStyle(theme.muted)
                Spacer()
                StatusLine(theme: theme, compact: true)
            }
            Spacer(minLength: 4)
            switch state {
            case .noDecks:
                Button("Choose decks", action: actions.openSettings).buttonStyle(.plain).font(theme.text(14, weight: .semibold))
            case .done:
                Image(systemName: "checkmark.circle").font(.system(size: 30, weight: .light)).foregroundStyle(theme.review)
                Text("All caught up").font(theme.text(12)).foregroundStyle(theme.muted)
            default:
                Text(state == .loading ? "–" : "\(totals.all)")
                    .font(theme.number(theme.numberSize * 0.82)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(state == .unreachable ? theme.muted : theme.foreground)
                Text(state == .unreachable ? "Anki closed" : "cards left").font(theme.text(12)).foregroundStyle(theme.muted)
            }
            Spacer(minLength: 4)
            if state == .counts {
                SplitBar(totals: totals, theme: theme, height: 5)
                HStack(spacing: 8) {
                    Text("\(totals.new)").foregroundStyle(theme.new)
                    Text("\(totals.learn)").foregroundStyle(theme.learn)
                    Text("\(totals.review)").foregroundStyle(theme.review)
                }
                .font(theme.text(11, weight: .semibold)).monospacedDigit()
            }
        }
        .padding(16)
        .frame(width: 172, height: 172, alignment: .leading)
        .widgetCard(theme, radius: 22)
        .contextMenu { Button("Settings…", action: actions.openSettings) }
    }
}

// MARK: - Pill

struct PillWidget: View {
    @Environment(AppModel.self) private var model
    @Environment(\.widgetActions) private var actions
    let theme: Theme

    var body: some View {
        let totals = model.totals
        let state = model.widgetState
        HStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(state == .loading ? "–" : "\(totals.all)").font(theme.number(20)).fontWeight(.semibold)
                Text(state == .unreachable ? "Anki closed" : "left").font(theme.text(12)).foregroundStyle(theme.muted)
            }
            Rectangle().fill(theme.line).frame(width: 1, height: 20)
            HStack(spacing: 10) {
                Text("\(totals.new)").foregroundStyle(theme.new)
                Text("\(totals.learn)").foregroundStyle(theme.learn)
                Text("\(totals.review)").foregroundStyle(theme.review)
            }
            .font(theme.text(12, weight: .semibold))
            Spacer(minLength: 0)
            StatusLine(theme: theme, compact: true)
            if state == .counts {
                ThemedButton(title: "Review", theme: theme, action: actions.startReview)
            }
        }
        .monospacedDigit()
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(width: 320, height: 48)
        .widgetCard(theme, radius: 24)
        .contextMenu { Button("Settings…", action: actions.openSettings) }
    }
}
