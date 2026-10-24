import SwiftUI
import KeyboardShortcuts

@main
struct AnkiDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(delegate: delegate)
        } label: {
            MenuBarLabel(model: delegate.model)
        }
    }
}

private struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.stack")
            if model.prefs.showCountInMenuBar && model.connection == .connected && !model.counted.isEmpty {
                Text("\(model.totals.all)").monospacedDigit()
            }
        }
    }
}

private struct MenuContent: View {
    let delegate: AppDelegate

    var body: some View {
        Button("Show or Hide Widget") { delegate.widget?.toggle() }
        Button("Review Now") { delegate.startReview() }
            .disabled(delegate.model.totals.all == 0 || delegate.model.connection != .connected)
        Button("Sync Now") { Task { await delegate.model.syncNow() } }
            .disabled(delegate.model.connection != .connected)
        Divider()
        Button("Settings…") { delegate.showSettings() }
            .keyboardShortcut(",")
        Button("Connect to Anki…") { delegate.showConnect() }
        Button("How to Use Anki Desk") { delegate.showHowTo() }
        Divider()
        Button("Quit Anki Desk") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel(prefs: Preferences())
    lazy var review = ReviewSession(model: model)
    private(set) var widget: WidgetController?
    private var settingsWindow: NSWindow?
    private var connectWindow: NSWindow?
    private var howToWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        let actions = WidgetActions(
            openSettings: { [weak self] in self?.showSettings() },
            openHowTo: { [weak self] in self?.showHowTo() },
            startReview: { [weak self] in self?.startReview() }
        )
        let widget = WidgetController(model: model, review: review, actions: actions)
        self.widget = widget
        widget.show()
        model.start()
        KeyboardShortcuts.onKeyUp(for: .toggleWidget) { [weak self] in self?.widget?.toggle() }
        if !model.prefs.finishedSetup { showConnect() }
    }

    func startReview() {
        widget?.summon()
        Task { await review.start() }
    }

    func showSettings() {
        settingsWindow = present(settingsWindow, title: "Anki Desk Settings") {
            SettingsView { [weak self] in self?.showHowTo() }.environment(self.model)
        }
    }

    func showHowTo() {
        howToWindow = present(howToWindow, title: "How to Use Anki Desk") { HowToView() }
    }

    func showConnect() {
        connectWindow = present(connectWindow, title: "Connect to Anki") {
            ConnectView { [weak self] in
                self?.connectWindow?.close()
                self?.showHowTo()
                self?.showSettings()
            }
            .environment(self.model)
        }
    }

    private func present(_ existing: NSWindow?, title: String, content: () -> some View) -> NSWindow {
        let window = existing ?? {
            let w = NSWindow(contentViewController: NSHostingController(rootView: content()))
            w.title = title
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            return w
        }()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
