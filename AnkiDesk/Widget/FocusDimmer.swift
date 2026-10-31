import AppKit

/// Focus mode's background: a blurred, darkened window over each screen, behind the widget. It takes clicks,
/// so a stray one can't reach the apps behind it during a review.
final class FocusDimmer {
    /// Above the menu bar and the Dock.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    static let widgetLevel = NSWindow.Level(rawValue: level.rawValue + 1)
    /// How dark the black over the blur is.
    private static let tint = 0.45

    private var windows: [NSWindow] = []
    private var isOn = false
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
    }

    func set(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        if on {
            cover(alpha: 0)
            fade(to: 1)
        } else {
            fade(to: 0) { [weak self] in
                guard let self, !self.isOn else { return }
                self.removeWindows()
            }
        }
    }

    private func screensChanged() {
        guard isOn else { return }
        cover(alpha: 1)
    }

    private func cover(alpha: Double) {
        removeWindows()
        windows = NSScreen.screens.map { Self.window(on: $0, alpha: alpha) }
    }

    private func removeWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }

    private func fade(to alpha: Double, completion: (@MainActor () -> Void)? = nil) {
        let windows = windows
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            windows.forEach { $0.animator().alphaValue = alpha }
        } completionHandler: {
            MainActor.assumeIsolated { completion?() }
        }
    }

    private static func window(on screen: NSScreen, alpha: Double) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = blurView()
        window.alphaValue = alpha
        window.hasShadow = false
        window.level = level
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.setFrame(screen.frame, display: false)
        window.orderFrontRegardless()
        return window
    }

    /// Blurs what's behind the window, under a black tint. The dark appearance keeps the blur from washing out.
    private static func blurView() -> NSView {
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .darkAqua)
        let shade = NSView()
        shade.wantsLayer = true
        shade.layer?.backgroundColor = NSColor.black.withAlphaComponent(tint).cgColor
        shade.autoresizingMask = [.width, .height]
        blur.addSubview(shade)
        return blur
    }
}
