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

    /// Grow and shrink from the top edge, so the widget stays where it was put.
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var rect = frameRect
        if frame.width > 0, rect.size != frame.size, rect.origin == frame.origin {
            rect.origin.y = frame.maxY - rect.height
        }
        super.setFrame(rect, display: flag)
        invalidateShadow()
    }
}

/// Owns the widget window: where it sits, which level it lives on, and the show/hide shortcut.
final class WidgetController: NSObject, NSWindowDelegate {
    let panel = WidgetPanel()
    private let model: AppModel
    private let review: ReviewSession
    /// Brought forward by the shortcut: floats and takes the keyboard until it loses focus.
    private var summoned = false

    init(model: AppModel, review: ReviewSession, actions: WidgetActions) {
        self.model = model
        self.review = review
        super.init()
        let root = WidgetRootView()
            .environment(model)
            .environment(review)
            .environment(\.widgetActions, actions)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hosting
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

    func windowDidResignKey(_ notification: Notification) {
        guard summoned else { return }
        summoned = false
        applyLevel()
    }

    private func applyLevel() {
        let prefs = model.prefs
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
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.applyLevel()
                self?.observePrefs()
            }
        }
    }
}
