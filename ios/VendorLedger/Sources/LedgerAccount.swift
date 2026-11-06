import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
import WebKit
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions

enum LedgerAccountError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return ledgerLocalized(value) }; return nil }
}

// No credentials or identity tokens ever enter the web view or localStorage.
@MainActor
final class LedgerAccountStore: ObservableObject {
    @Published private(set) var user: FirebaseAuth.User?
    @Published private(set) var configured = false
    @Published var busy = false
    @Published var message = ""
    @Published var error = ""
    @Published var webRevision = UUID()
    private var listener: AuthStateDidChangeListenerHandle?
    private var deletionInProgress = false
    private var previousStorageKey = "guest"

    init() {
        // The optional configuration is supplied by the owner's Firebase project.
        // Never create a fake user or claim a remote save when configuration is absent.
        guard let file = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: file),
              options.bundleID == Bundle.main.bundleIdentifier else { return }
        if FirebaseApp.app() == nil { FirebaseApp.configure(options: options) }
        configured = true
        user = Auth.auth().currentUser
        previousStorageKey = storageKey
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, current in
            Task { @MainActor in
                guard let self, !self.deletionInProgress else { return }
                self.user = current
                if self.previousStorageKey != self.storageKey {
                    self.previousStorageKey = self.storageKey
                    self.webRevision = UUID()
                }
            }
        }
    }

    var storageKey: String { user?.uid ?? "guest" }
    var dataStore: WKWebsiteDataStore {
        guard let uid = user?.uid else { return .default() }
        return WKWebsiteDataStore(forIdentifier: Self.identifier(uid))
    }
    static func identifier(_ uid: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(("ledger.account." + uid).utf8)).prefix(16))
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }
    var verified: Bool { user?.isEmailVerified == true }
    var appleLinked: Bool { user?.providerData.contains(where: { $0.providerID == "apple.com" }) == true }
    var passwordLinked: Bool { user?.providerData.contains(where: { $0.providerID == "password" }) == true }

    func perform(_ action: () async throws -> Void) async {
        guard !busy else { return }
        busy = true; error = ""; message = ""
        defer { busy = false }
        do { try await action() }
        catch { self.error = Self.friendly(error) }
    }

    func email(_ address: String, password: String, create: Bool) async throws {
        guard configured else { throw LedgerAccountError.message("帳號服務尚未啟用，請先使用本機帳本。") }
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.contains("@"), password.count >= 8 else {
            throw LedgerAccountError.message("請輸入有效 Email，密碼至少 8 個字元。")
        }
        let result: AuthDataResult
        if create {
            result = try await Auth.auth().createUser(withEmail: address, password: password)
            // Account creation succeeded even if sending the verification email fails.
            do { try await result.user.sendEmailVerification(); message = ledgerLocalized("帳號已建立，請到信箱驗證 Email 後使用雲端備份。") }
            catch { message = ledgerLocalized("帳號已建立；驗證信尚未寄出，可按重新寄送。") }
        } else {
            result = try await Auth.auth().signIn(withEmail: address, password: password)
            message = ledgerLocalized("已登入；帳目會自動保存在此帳號的裝置空間。")
        }
        user = result.user
        webRevision = UUID()
    }

    func sendVerification() async throws {
        guard let user else { throw LedgerAccountError.message("請先登入。") }
        try await user.sendEmailVerification()
        message = ledgerLocalized("驗證信已寄出，請確認信箱及垃圾郵件。")
    }
    func refreshVerification() async throws {
        guard let current = Auth.auth().currentUser else { throw LedgerAccountError.message("請先登入。") }
        try await current.reload()
        _ = try await current.getIDToken(forcingRefresh: true)
        user = Auth.auth().currentUser
        message = verified ? ledgerLocalized("Email 已驗證，可使用雲端備份。") : ledgerLocalized("尚未完成 Email 驗證。")
    }
    func resetPassword(_ email: String) async throws {
        guard configured, email.contains("@") else { throw LedgerAccountError.message("請先輸入 Email。") }
        try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
        message = ledgerLocalized("若此 Email 可重設密碼，將收到重設信件，請查看信箱。")
    }
    func signOut() throws {
        try Auth.auth().signOut()
        user = nil; webRevision = UUID()
        message = ledgerLocalized("已登出，回到原本的本機訪客帳本。帳號資料未被刪除。")
    }

    enum ApplePurpose: Equatable { case signIn, link, delete }
    func completeApple(_ result: Result<ASAuthorization, Error>, nonce: String?, purpose: ApplePurpose) async throws {
        guard configured else { throw LedgerAccountError.message("帳號服務尚未啟用，請先使用本機帳本。") }
        let authorization = try result.get()
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
              let token = apple.identityToken, let idToken = String(data: token, encoding: .utf8),
              let nonce, !nonce.isEmpty else { throw LedgerAccountError.message("Apple 登入驗證未完成，請重試。") }
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: nil)
        switch purpose {
        case .signIn:
            user = try await Auth.auth().signIn(with: credential).user
            webRevision = UUID()
            message = ledgerLocalized("已使用 Apple 登入。")
        case .link:
            guard let current = user else { throw LedgerAccountError.message("請先登入。") }
            user = try await current.link(with: credential).user
            message = ledgerLocalized("已連結 Apple，之後兩種方式可登入同一帳本。")
        case .delete:
            guard let current = user else { throw LedgerAccountError.message("請先登入。") }
            _ = try await current.reauthenticate(with: credential)
            guard let code = apple.authorizationCode, let codeString = String(data: code, encoding: .utf8) else {
                throw LedgerAccountError.message("無法取得 Apple 授權碼，帳號尚未刪除。")
            }
            try await Auth.auth().revokeToken(withAuthorizationCode: codeString)
            try await deleteAccount()
        }
    }
    func linkEmail(_ address: String, password: String) async throws {
        guard let current = user, !passwordLinked else { throw LedgerAccountError.message("此帳號已設定 Email 登入。") }
        guard address.contains("@"), password.count >= 8 else { throw LedgerAccountError.message("請輸入有效 Email，密碼至少 8 個字元。") }
        user = try await current.link(with: EmailAuthProvider.credential(withEmail: address, password: password)).user
        try await user?.sendEmailVerification()
        message = ledgerLocalized("已連結 Email，請完成信箱驗證。")
    }
    func deleteWithPassword(_ password: String) async throws {
        guard let current = user, let email = current.email, !appleLinked else {
            throw LedgerAccountError.message("請使用 Apple 重新驗證後刪除帳號。")
        }
        _ = try await current.reauthenticate(with: EmailAuthProvider.credential(withEmail: email, password: password))
        try await deleteAccount()
    }
    private func deleteAccount() async throws {
        guard let current = user else { throw LedgerAccountError.message("請先登入。") }
        let uid = current.uid
        _ = try await current.getIDToken(forcingRefresh: true)
        deletionInProgress = true
        defer { deletionInProgress = false }
        // The callable checks recent authentication, locks writes, deletes all cloud
        // snapshots recursively, then removes the Auth user. Never just hide the UI.
        let result = try await Functions.functions(region: "asia-east1").httpsCallable("deleteLedgerAccount").call()
        guard let body = result.data as? [String: Any], body["deleted"] as? Bool == true else {
            throw LedgerAccountError.message("刪除尚未確認，請稍後重試；不要重新註冊。")
        }
        let store = WKWebsiteDataStore(forIdentifier: Self.identifier(uid))
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        let recovery = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AccountRecovery/" + LedgerAccountStore.identifier(uid).uuidString)
        try? FileManager.default.removeItem(at: recovery)
        try? Auth.auth().signOut()
        user = nil; webRevision = UUID()
        message = ledgerLocalized("帳號、雲端帳本與此裝置的帳號資料已刪除。訂閱仍須另向 Apple 取消。")
    }

    static func nonce() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw LedgerAccountError.message("無法產生登入驗證碼，請重試。")
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    static func sha256(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func friendly(_ error: Error) -> String {
        if error is LedgerAccountError { return error.localizedDescription }
        if (error as NSError).domain == ASAuthorizationError.errorDomain && (error as NSError).code == ASAuthorizationError.canceled.rawValue { return ledgerLocalized("已取消 Apple 登入，資料未變更。") }
        switch AuthErrorCode(rawValue: (error as NSError).code) {
        case .emailAlreadyInUse, .credentialAlreadyInUse, .accountExistsWithDifferentCredential:
            return ledgerLocalized("此登入方式已綁定其他帳號。請先用原登入方式進入，再連結登入方式；不會自動合併帳本。")
        case .wrongPassword, .invalidCredential, .userNotFound: return ledgerLocalized("Email 或密碼不正確，請重試或重設密碼。")
        case .networkError: return ledgerLocalized("目前無法連線，裝置內的帳本仍保留。")
        case .requiresRecentLogin: return ledgerLocalized("請重新登入後再執行此操作。")
        case .tooManyRequests: return ledgerLocalized("嘗試次數過多，請稍後重試。")
        default: return ledgerLocalized("操作未完成，請檢查連線與帳號服務設定後重試。")
        }
    }
}
