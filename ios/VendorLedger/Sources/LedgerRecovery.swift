import SwiftUI
import WebKit

struct LedgerRecoveryProfile: Identifiable {
    let id: String
    let name: String
    let count: Int
}

struct LedgerRecoveryExport: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class LedgerRecoveryModel: ObservableObject {
    @Published var profiles: [LedgerRecoveryProfile] = []
    @Published var message = ledgerLocalized("正在讀取此裝置的帳本…")
    @Published var exported: LedgerRecoveryExport?
    @Published var isExporting = false
    weak var webView: WKWebView?

    func loaded(_ web: WKWebView) async {
        webView = web
        do {
            let value = try await web.evaluateJavaScript(LedgerRecoveryScripts.profiles)
            guard let json = value as? String, let data = json.data(using: .utf8),
                  let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                message = ledgerLocalized("無法讀取帳本清單，請重新開啟備份頁。")
                return
            }
            profiles = rows.compactMap { row in
                guard let id = row["id"] as? String else { return nil }
                return LedgerRecoveryProfile(id: id, name: row["name"] as? String ?? id, count: row["count"] as? Int ?? 0)
            }
            message = profiles.isEmpty ? ledgerLocalized("此裝置沒有可匯出的帳本。") : ledgerLocalized("選擇攤商即可匯出，無需有效訂閱。")
        } catch {
            message = ledgerLocalized("讀取帳本失敗，請重新開啟備份頁。")
        }
    }

    func export(_ profile: LedgerRecoveryProfile) async {
        guard let web = webView, !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            // JSON encoding prevents profile names/IDs becoming executable script.
            let encoded = try JSONSerialization.data(withJSONObject: [profile.id])
            let literal = String(decoding: encoded, as: UTF8.self)
            let script = "(function(){ const id = \(literal)[0]; " + LedgerRecoveryScripts.exportBody + " })()"
            guard let text = try await web.evaluateJavaScript(script) as? String,
                  let data = text.data(using: .utf8), data.count < 25_000_000 else {
                message = ledgerLocalized("備份資料無法讀取或檔案過大。")
                return
            }
            _ = try JSONSerialization.jsonObject(with: data)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("攤商備份-\(UUID().uuidString).json")
            try data.write(to: url, options: .atomic)
            exported = LedgerRecoveryExport(url: url)
            message = ledgerLocalized("備份已準備完成，請選擇儲存或分享位置。")
        } catch {
            message = ledgerLocalized("備份未完成，請重新開啟後重試。")
        }
    }
}

// These scripts only read localStorage and match the app's existing per-vendor
// vendor_v29_backup v1 format, including options and original legacy archives.
enum LedgerRecoveryScripts {
    static let profiles = #"""
    (function(){
      const read = (k,fallback) => { const raw=localStorage.getItem(k); return raw===null?fallback:JSON.parse(raw); };
      const keys=['vb_daily_v29','vb_purchase_v29','vb_fixed_v29','vb_processing_v29','vb_equip_v29','vb_inventory_v29','vb_memo_v29'];
      const profiles=read('vb_profiles_v30',[]);
      const stored=keys.flatMap(k=>read(k,[]));
      const ids=[...new Set([...profiles.map(p=>p.id),...stored.map(r=>r.vendorId)])].filter(id=>typeof id==='string');
      return JSON.stringify(ids.map(id=>({id,name:profiles.find(p=>p.id===id)?.name||id,count:stored.filter(r=>r.vendorId===id).length})));
    })()
    """#
    static let exportBody = #"""
    const read=(k,fallback)=>{ const raw=localStorage.getItem(k); return raw===null?fallback:JSON.parse(raw); };
    const keys=['vb_daily_v29','vb_purchase_v29','vb_fixed_v29','vb_processing_v29','vb_equip_v29','vb_inventory_v29','vb_memo_v29'];
    const data=Object.fromEntries(keys.map(k=>[k,read(k,[]).filter(r=>r.vendorId===id)]));
    const options={};
    for(let i=0;i<localStorage.length;i++){
      const k=localStorage.key(i);
      if(k.startsWith('vb_options_')&&k.endsWith('_'+id)) options[k.slice(0,-id.length)]=read(k,[]);
    }
    return JSON.stringify({app:'vendor_v29_backup',version:1,exportedAt:new Date().toISOString(),vendor:read('vb_profiles_v30',[]).find(p=>p.id===id),data,options,legacyArchives:read('vb_legacy_archives_v31',{})[id]||[]});
    """#
}

@MainActor
struct LedgerRecoveryView: View {
    @StateObject private var model = LedgerRecoveryModel()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(model.message).font(.footnote).foregroundStyle(.secondary).padding()
                List(model.profiles) { profile in
                    Button {
                        Task { await model.export(profile) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name).font(.headline)
                                Text("\(profile.count) " + ledgerLocalized("筆資料")).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                        }
                    }.disabled(model.isExporting)
                }
                // Reuse exactly the bundled file URL and persistent WebKit store.
                // The hidden web view never exposes paid editing UI or sends data.
                LedgerRecoveryWebView(model: model).frame(height: 1).opacity(0)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
            .navigationTitle(ledgerLocalized("匯出既有帳本"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(ledgerLocalized("完成")) { dismiss() } } }
            .sheet(item: $model.exported) { item in LedgerBackupShareSheet(url: item.url) }
        }
    }
}

struct LedgerRecoveryWebView: UIViewRepresentable {
    let model: LedgerRecoveryModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = context.coordinator
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    class Coordinator: NSObject, WKNavigationDelegate {
        let model: LedgerRecoveryModel
        init(model: LedgerRecoveryModel) { self.model = model }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in await model.loaded(webView) }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.request.url?.isFileURL == true || action.request.url?.scheme == "about" ? .allow : .cancel)
        }
    }
}

struct LedgerBackupShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url) }
        return sheet
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
