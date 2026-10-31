import AppKit
import SwiftUI

/// A borderless panel that can be dragged anywhere and remembers where it was.
final class WidgetPanel: NSPanel {
    var onEscape: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 360),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    /// Fits the window to the widget, growing and shrinking from the top edge so it stays where it was put.
    func fit(_ size: CGSize) {
        let size = CGSize(width: ceil(size.width), height: ceil(size.height))
        guard size.width > 0, size.height > 0, size != frame.size else { return }
        setFrame(NSRect(x: frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height), display: true)
        invalidateShadow()
    }
}

/// Owns the widget window: where it sits, which level it lives on, and the show/hide shortcut.
final class WidgetController: NSObject, NSWindowDelegate {
    let panel = WidgetPanel()
    private let model: AppModel
    private let review: ReviewSession
    private let dimmer = FocusDimmer()
    /// Brought forward by the shortcut: floats and takes the keyboard until it loses focus.
    private var summoned = false

    init(model: AppModel, review: ReviewSession, actions: WidgetActions) {
        self.model = model
        self.review = review
        super.init()
        // The widget reports its size and the panel follows, after layout. Letting the hosting view
        // resize the window itself re-enters layout and can recurse until the stack overflows.
        let root = WidgetRootView()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak panel] size in
                DispatchQueue.main.async { panel?.fit(size) }
            }
            .environment(model)
            .environment(review)
            .environment(\.widgetActions, actions)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.escape() }
        if !panel.setFrameUsingName("AnkiDeskWidget"), let screen = NSScreen.main?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: screen.minX + 40, y: screen.maxY - 40))
        }
        panel.setFrameAutosaveName("AnkiDeskWidget")
        applyLevel()
        observePrefs()
    }

    func show() {
        panel.orderFrontRegardless()
    }

    /// The global shortcut: show and focus the widget, or hide it if it already has focus.
    func toggle() {
        if panel.isVisible && panel.isKeyWindow {
            hide()
        } else {
            summon()
        }
    }

    func summon() {
        summoned = true
        applyLevel()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        if review.isActive { review.stop() }
        panel.orderOut(nil)
        summoned = false
        applyLevel()
    }

    private func escape() {
        if review.isActive { review.stop() } else { hide() }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        applyLevel()
    }

    func windowDidResignKey(_ notification: Notification) {
        summoned = false
        applyLevel()
    }

    private func applyLevel() {
        let prefs = model.prefs
        // Only while the widget has the keyboard: Anki Desk isn't in the app switcher, so after switching
        // away there'd be no way past a dimmed screen to the app the user went to.
        let focusing = prefs.focusMode && review.isActive && panel.isKeyWindow
        dimmer.set(focusing)
        if focusing {
            panel.level = FocusDimmer.widgetLevel
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.ignoresMouseEvents = false
            return
        }
        if summoned {
            panel.level = .floating
            panel.ignoresMouseEvents = false
            return
        }
        switch prefs.level {
        case .onTop:
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        case .normal:
            panel.level = .normal
            panel.collectionBehavior = [.canJoinAllSpaces]
        case .desktop:
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        }
        panel.ignoresMouseEvents = prefs.clickThrough
    }

    private func observePrefs() {
        withObservationTracking {
            _ = model.prefs.level
            _ = model.prefs.clickThrough
            _ = model.prefs.focusMode
            _ = review.isActive
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.applyLevel()
                self?.observePrefs()
            }
        }
    }
}
