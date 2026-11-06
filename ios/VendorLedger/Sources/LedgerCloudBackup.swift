import SwiftUI
import WebKit
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

struct LedgerCloudHead {
    let revision: String
    let date: Date?
    let chunks: Int
    let digest: String
    let bytes: Int
}

@MainActor
final class LedgerCloudBackup: ObservableObject {
    @Published var head: LedgerCloudHead?
    @Published var busy = false
    @Published var message = ""
    @Published var error = ""
    @Published var recoveryExport: LedgerRecoveryExport?
    @Published var ready = false
    @Published var recoveryFiles: [URL] = []
    weak var webView: WKWebView?
    private let account: LedgerAccountStore
    private let uid: String
    init(account: LedgerAccountStore) { self.account = account; self.uid = account.user?.uid ?? "" }
    private func checkUser() throws {
        guard !uid.isEmpty, account.user?.uid == uid, Auth.auth().currentUser?.uid == uid,
              account.verified else { throw LedgerAccountError.message("請先登入並完成 Email 驗證。") }
    }
    private var root: DocumentReference { Firestore.firestore().collection("ledgerAccounts").document(uid) }
    func inspect() async throws {
        try checkUser()
        head = try Self.decode(try await root.getDocument(source: .server))
    }
    private static func decode(_ document: DocumentSnapshot) throws -> LedgerCloudHead? {
        guard document.exists, let d = document.data() else { return nil }
        guard let revision = d["revision"] as? String, UUID(uuidString: revision) != nil,
              let chunks = d["chunks"] as? Int, (1...120).contains(chunks),
              let bytes = d["bytes"] as? Int, (1...25_000_000).contains(bytes),
              let digest = d["digest"] as? String, digest.count == 64 else {
            throw LedgerAccountError.message("雲端備份資訊不完整，未覆寫任何資料。")
        }
        return LedgerCloudHead(revision: revision, date: (d["updatedAt"] as? Timestamp)?.dateValue(), chunks: chunks, digest: digest, bytes: bytes)
    }
    func run(_ operation: () async throws -> Void) async {
        guard !busy else { return }
        busy = true; error = ""; message = ""
        defer { busy = false }
        do { try await operation() }
        catch let e as LedgerAccountError { error = e.localizedDescription }
        catch let e as NSError where e.domain == "LedgerCloudConflict" { error = e.localizedDescription }
        catch { self.error = ledgerLocalized("雲端操作未完成，裝置資料仍保留。請確認連線、Email 驗證及雲端服務設定。") }
    }
    private func snapshot() async throws -> String {
        guard ready, let web = webView,
              let text = try await web.evaluateJavaScript("LedgerAccountStorage.read(localStorage)") as? String,
              text.utf8.count <= 25_000_000 else { throw LedgerAccountError.message("帳本尚未讀取完成，或備份超過 25 MB。") }
        return text
    }
    func upload() async throws {
        try checkUser()
        let expected = head?.revision // This exact inspected version must still be current at commit.
        let raw = try await snapshot(), bytes = Data(raw.utf8), revision = UUID().uuidString
        let payload = bytes.base64EncodedString(), chunkSize = 400_000
        let parts = stride(from: 0, to: payload.count, by: chunkSize).map { start -> String in
            let lower = payload.index(payload.startIndex, offsetBy: start)
            let upper = payload.index(lower, offsetBy: min(chunkSize, payload.count - start))
            return String(payload[lower..<upper])
        }
        let snapshotRef = root.collection("snapshots").document(revision)
        // Stage immutable chunks first. A failed transfer never publishes a partial backup.
        for (i,part) in parts.enumerated() {
            try checkUser()
            try await snapshotRef.collection("chunks").document(String(i)).setData(["payload":part])
        }
        let digest = SHA256.hash(data: bytes).map { String(format:"%02x",$0) }.joined()
        let metadata: [String:Any] = ["revision":revision,"chunks":parts.count,"digest":digest,"bytes":bytes.count,"updatedAt":FieldValue.serverTimestamp(),"format":1]
        try await snapshotRef.setData(metadata)
        try checkUser()
        let root = self.root
        _ = try await Firestore.firestore().runTransaction { transaction, errorPointer -> Any? in
            do {
                let remote = try transaction.getDocument(root)
                guard remote.data()?["revision"] as? String == expected else {
                    throw NSError(domain:"LedgerCloudConflict",code:409,userInfo:[NSLocalizedDescriptionKey:ledgerLocalized("另一台裝置已更新雲端備份。請重新檢查，核對後再決定儲存或還原。")])
                }
                transaction.setData(metadata, forDocument: root)
            } catch { errorPointer?.pointee = error as NSError }
            return nil
        }
        try await inspect()
        message = ledgerLocalized("雲端備份已完成。更換裝置後可登入同一帳號並還原。")
    }
    func restore() async throws {
        try checkUser()
        guard let chosen = head, ready, let web = webView else { throw LedgerAccountError.message("尚無可還原的雲端備份。") }
        var payload = ""
        for i in 0..<chosen.chunks {
            try checkUser()
            let document = try await root.collection("snapshots").document(chosen.revision).collection("chunks").document(String(i)).getDocument(source: .server)
            guard let part = document.data()?["payload"] as? String, part.count <= 400_000 else { throw LedgerAccountError.message("雲端備份分段缺漏，未變更本機資料。") }
            payload += part
        }
        guard let data = Data(base64Encoded: payload), data.count == chosen.bytes,
              data.count <= 25_000_000,
              SHA256.hash(data: data).map({String(format:"%02x",$0)}).joined() == chosen.digest,
              let text = String(data: data, encoding: .utf8) else { throw LedgerAccountError.message("雲端備份檢查失敗，未變更本機資料。") }
        try await applySnapshot(text)
    }
    func importSnapshot(_ text: String) async throws {
        try checkUser()
        try await applySnapshot(text)
    }
    private var recoveryFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AccountRecovery/" + LedgerAccountStore.identifier(uid).uuidString)
    }
    func loadRecoveryFiles() {
        recoveryFiles = ((try? FileManager.default.contentsOfDirectory(at:recoveryFolder,includingPropertiesForKeys:nil)) ?? []).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
    func exportSnapshot() async throws {
        try checkUser()
        let text = try await snapshot()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("完整帳號備份-" + UUID().uuidString + ".json")
        try Data(text.utf8).write(to:file,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        recoveryExport = LedgerRecoveryExport(url:file)
    }
    private func applySnapshot(_ text: String) async throws {
        guard let web = webView, ready else { throw LedgerAccountError.message("帳本尚未讀取完成，或備份超過 25 MB。") }
        _ = try await web.callAsyncJavaScript("return LedgerAccountStorage.validate(snapshot).version;", arguments:["snapshot":text], in:nil, contentWorld:.page)
        // Keep an on-disk recovery file before replacing any local ledger table.
        let old = try await snapshot()
        let folder = recoveryFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("還原前帳本-" + String(Int(Date().timeIntervalSince1970)) + "-" + UUID().uuidString + ".json")
        try Data(old.utf8).write(to:file,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        try checkUser()
        _ = try await web.callAsyncJavaScript("return LedgerAccountStorage.apply(localStorage, snapshot);", arguments:["snapshot":text], in:nil, contentWorld:.page)
        message = ledgerLocalized("已還原雲端帳本；還原前的本機副本可匯出保管。")
        loadRecoveryFiles()
        recoveryExport = LedgerRecoveryExport(url:file)
        account.webRevision = UUID()
    }
}

// A noninteractive view of the same account store also makes backups available
// when a subscription has expired. It cannot unlock paid ledger editing.
struct LedgerAccountBackupWeb: UIViewRepresentable {
    let store: WKWebsiteDataStore
    let model: LedgerCloudBackup
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = store
        let web = WKWebView(frame:.zero,configuration:configuration)
        web.navigationDelegate = context.coordinator; model.webView = web
        if let file = Bundle.main.url(forResource:"index",withExtension:"html",subdirectory:"Web") {
            web.loadFileURL(file,allowingReadAccessTo:file.deletingLastPathComponent())
        }
        return web
    }
    func updateUIView(_ web: WKWebView, context: Context) {}
    class Coordinator: NSObject, WKNavigationDelegate {
        let model: LedgerCloudBackup
        init(_ model: LedgerCloudBackup) { self.model = model }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { model.ready = true }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.request.url?.isFileURL == true || action.request.url?.scheme == "about" ? .allow : .cancel)
        }
    }
}
