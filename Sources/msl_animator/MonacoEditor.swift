import SwiftUI
import WebKit

struct MonacoEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        // Add message handlers
        userContentController.add(context.coordinator, name: "shaderUpdate")
        userContentController.add(context.coordinator, name: "editorLoaded")

        webConfiguration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.setValue(false, forKey: "drawsBackground")  // Transparent background
        context.coordinator.webView = webView

        // Load the local HTML file
        if let url = Bundle.module.url(forResource: "editor", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // We only push updates if the local content differs significantly or if it's an external change
        // But to avoid loops, we rely on the coordinator to manage the state
        if context.coordinator.isEditorLoaded && context.coordinator.lastTextSent != text {
            // Escape the string for JS
            let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")

            let js = "updateCode(\"\(escapedText)\");"
            webView.evaluateJavaScript(js)
            context.coordinator.lastTextSent = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: MonacoEditor
        weak var webView: WKWebView?
        var isEditorLoaded = false
        var lastTextSent = ""

        init(_ parent: MonacoEditor) {
            self.parent = parent
        }

        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            if message.name == "shaderUpdate", let code = message.body as? String {
                // Receive code from JS
                if code != parent.text {
                    parent.text = code
                    lastTextSent = code  // Avoid bouncing back
                }
            } else if message.name == "editorLoaded" {
                isEditorLoaded = true
                // Send initial text
                let escapedText = parent.text.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "")
                let js = "updateCode(\"\(escapedText)\");"
                webView?.evaluateJavaScript(js)
                lastTextSent = parent.text
            }
        }
    }
}
