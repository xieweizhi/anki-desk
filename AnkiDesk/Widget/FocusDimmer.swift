import AppKit
import SwiftUI

/// Focus mode's background: a blurred, darkened window over each screen, behind the widget. It takes clicks,
/// so a stray one can't reach the apps behind it during a review.
final class FocusDimmer {
    /// Above the menu bar and the Dock.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    static let widgetLevel = NSWindow.Level(rawValue: level.rawValue + 1)
    /// How dark the black over the blur is.
    private static let tint = 0.5
    /// How much of the blur shows. macOS's blur has one strength, so a little of the sharp desktop is let through.
    private static let strength = 0.85

    /// The hint on the dimmed background was clicked.
    var onExit: () -> Void = {}

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
            fade(to: Self.strength)
        } else {
            fade(to: 0) { [weak self] in
                guard let self, !self.isOn else { return }
                self.removeWindows()
            }
        }
    }

    private func screensChanged() {
        guard isOn else { return }
        cover(alpha: Self.strength)
    }

    private func cover(alpha: Double) {
        removeWindows()
        windows = NSScreen.screens.map { window(on: $0, alpha: alpha) }
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

    private func window(on screen: NSScreen, alpha: Double) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = blurView()
        window.alphaValue = alpha
        window.hasShadow = false
        window.level = Self.level
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.setFrame(screen.frame, display: false)
        window.orderFrontRegardless()
        return window
    }

    /// Blurs what's behind the window, under a black tint. The dark appearance keeps the blur from washing out.
    private func blurView() -> NSView {
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .darkAqua)
        let shade = NSView()
        shade.wantsLayer = true
        shade.layer?.backgroundColor = NSColor.black.withAlphaComponent(Self.tint).cgColor
        shade.autoresizingMask = [.width, .height]
        blur.addSubview(shade)
        let hint = FocusExitHintView(rootView: FocusExitHint { [weak self] in self?.onExit() })
        hint.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.centerXAnchor.constraint(equalTo: blur.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: blur.bottomAnchor, constant: -48),
        ])
        return blur
    }
}

/// Takes the first click: these windows never become key, so a click has nothing to activate first.
private final class FocusExitHintView: NSHostingView<FocusExitHint> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Says how to leave focus mode; clicking it does the same as Esc.
struct FocusExitHint: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("esc")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.5)))
                Text("Exit focus").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(.white.opacity(0.14), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Exit focus")
    }
}
