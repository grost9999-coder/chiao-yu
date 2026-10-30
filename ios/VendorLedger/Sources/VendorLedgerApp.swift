import SwiftUI
import WebKit
import UniformTypeIdentifiers

@main
struct VendorLedgerApp: App {
    var body: some Scene {
        WindowGroup { SubscriptionRootView().preferredColorScheme(.light) }
    }
}

struct LedgerView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController.add(context.coordinator, name: "backup")
        // Anchor downloads of blob JSON use the native share sheet on iPhone.
        let bridge = #"""
        document.addEventListener('click', async function(e) {
          const a=e.target.closest && e.target.closest('a[download]');
          if(!a || !a.href.startsWith('blob:')) return;
          e.preventDefault(); e.stopImmediatePropagation();
          try {
            const response=await fetch(a.href); const text=await response.text();
            JSON.parse(text);
            window.webkit.messageHandlers.backup.postMessage({name:a.download,text:text});
          } catch(error) { alert('備份失敗：'+error.message); }
        },true);
        """#
        config.userContentController.addUserScript(WKUserScript(source: bridge, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let web = WKWebView(frame: .zero, configuration: config)
        web.uiDelegate = context.coordinator
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = .systemBackground
        context.coordinator.webView = web
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "language", value: LedgerLanguage.resolved(UserDefaults.standard.string(forKey: "ledger.language") ?? "system"))]
            web.loadFileURL(components.url ?? url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "backup")
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
        weak var webView: WKWebView?
        var activeBackupURL: URL?
        func presenter() -> UIViewController? {
            guard var view = webView?.window?.rootViewController else { return nil }
            while let next = view.presentedViewController { view = next }
            return view
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  message.frameInfo.request.url?.isFileURL == true,
                  let body = message.body as? [String: Any],
                  let text = body["text"] as? String,
                  let data = text.data(using: .utf8), data.count < 25_000_000,
                  (try? JSONSerialization.jsonObject(with: data)) != nil,
                  let vc = presenter() else { return }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let rawName = (body["name"] as? String) ?? "攤商備份.json"
            let name = URL(fileURLWithPath: rawName).lastPathComponent
            let url = folder.appendingPathComponent(name.hasSuffix(".json") ? name : "攤商備份.json")
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
                activeBackupURL = url
                let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                sheet.popoverPresentationController?.sourceView = webView
                sheet.popoverPresentationController?.sourceRect = webView?.bounds ?? .zero
                sheet.completionWithItemsHandler = { _, _, _, _ in
                    try? FileManager.default.removeItem(at: folder)
                }
                vc.present(sheet, animated: true)
            } catch {
                let alert = UIAlertController(title: ledgerLocalized("備份失敗"), message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: ledgerLocalized("確定"), style: .default))
                vc.present(alert, animated: true)
            }
        }
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            guard let vc = presenter() else { completionHandler(); return }
            let alert = UIAlertController(title: ledgerLocalized("攤商記帳"), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: ledgerLocalized("確定"), style: .default) { _ in completionHandler() })
            vc.present(alert, animated: true)
        }
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            guard let vc = presenter() else { completionHandler(false); return }
            let alert = UIAlertController(title: ledgerLocalized("確認操作"), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: ledgerLocalized("取消"), style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: ledgerLocalized("確定"), style: .default) { _ in completionHandler(true) })
            vc.present(alert, animated: true)
        }
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            guard let vc = presenter() else { completionHandler(nil); return }
            let alert = UIAlertController(title: ledgerLocalized("輸入資料"), message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: ledgerLocalized("取消"), style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: ledgerLocalized("確定"), style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
            vc.present(alert, animated: true)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if url.isFileURL || url.scheme == "about" || url.scheme == "blob" {
                decisionHandler(.allow)
            } else {
                if navigationAction.navigationType == .linkActivated, ["https", "mailto", "tel"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
                decisionHandler(.cancel)
            }
        }
    }
}
