import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import WebKit

/// Renders one side of a card (Anki's HTML and CSS) with images from Anki's media folder.
struct CardWebView: NSViewRepresentable {
    let html: String
    let mediaDirectory: URL?
    let theme: Theme
    @Binding var height: CGFloat
    let onPlay: (Character, Int) -> Void

    static let mediaScheme = "ankidesk-media"
    static let playScheme = "ankidesk-play"

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.media, forURLScheme: Self.mediaScheme)
        let sizeScript = """
        new ResizeObserver(() => window.webkit.messageHandlers.size.postMessage(document.documentElement.scrollHeight))
          .observe(document.documentElement);
        """
        config.userContentController.addUserScript(WKUserScript(source: sizeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "size")
        let web = PassiveWebView(frame: .zero, configuration: config)
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = context.coordinator
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.media.directory = mediaDirectory
        let document = Self.document(html, theme: theme)
        if context.coordinator.loaded != document {
            context.coordinator.loaded = document
            web.loadHTMLString(document, baseURL: URL(string: "\(Self.mediaScheme)://media/"))
        }
    }

    static func document(_ body: String, theme: Theme) -> String {
        let fg = theme.isDark ? "#F2F3F5" : "#1C1B19"
        let night = theme.isDark ? "nightMode night_mode" : ""
        // Our overrides come after the card's own <style>, so they win where they must.
        return """
        <!doctype html><html><head><meta charset="utf-8"><style>
        html, body { margin: 0; padding: 0; background: transparent; }
        body { color: \(fg); font: 15px -apple-system, system-ui, sans-serif; padding: 14px 12px; overflow-wrap: anywhere; }
        img { max-width: 100%; height: auto; border-radius: 8px; }
        </style></head><body class="card \(night)">\(body)
        <style>
        .card { background: transparent !important; \(theme.isDark ? "color: \(fg) !important;" : "") }
        .ad-play { display: inline-flex; vertical-align: middle; width: 26px; height: 26px; border-radius: 13px;
          background: rgba(127,127,127,.2); align-items: center; justify-content: center; margin: 0 4px; color: inherit; }
        hr#answer { border: 0; border-top: 1px solid rgba(127,127,127,.3); margin: 14px 0; }
        </style></body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: CardWebView
        var loaded: String?
        let media = MediaSchemeHandler()

        init(_ parent: CardWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .allow }
            if url.scheme == CardWebView.playScheme {
                if let side = url.host()?.first, let index = Int(url.lastPathComponent) { parent.onPlay(side, index) }
                return .cancel
            }
            if url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return .allow
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            if let h = message.body as? Double { parent.height = min(max(h, 60), 420) }
            else if let h = message.body as? Int { parent.height = min(max(CGFloat(h), 60), 420) }
        }
    }
}

/// Keeps keyboard focus on the widget so Space and 1–4 reach the review buttons.
final class PassiveWebView: WKWebView {
    override var acceptsFirstResponder: Bool { false }
}

/// Serves `ankidesk-media://media/<file>` from Anki's collection.media folder.
final class MediaSchemeHandler: NSObject, WKURLSchemeHandler {
    var directory: URL?

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let dir = directory?.standardizedFileURL, let url = task.request.url else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let file = dir.appending(path: String(url.path.drop { $0 == "/" })).standardizedFileURL
        guard file.path.hasPrefix(dir.path + "/"), let data = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
