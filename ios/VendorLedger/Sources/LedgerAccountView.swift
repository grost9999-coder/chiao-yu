import SwiftUI
import AuthenticationServices
import WebKit
import UniformTypeIdentifiers

struct LedgerAccountShell: View {
    @StateObject private var account = LedgerAccountStore()
    @State private var showAccount = false
    var body: some View {
        VStack(spacing:0) {
            HStack {
                Text(ledgerLocalized(account.user == nil ? "本機訪客帳本" : "帳號獨立保存"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { showAccount = true } label: {
                    Label(ledgerLocalized(account.user == nil ? "登入／註冊" : "帳號與雲端備份"),systemImage:"person.crop.circle")
                        .font(.subheadline)
                }.accessibilityIdentifier("account.open")
            }.padding(.horizontal,18).padding(.vertical,8).background(.thinMaterial)
            SubscriptionRootView()
        }
        .environmentObject(account)
        .sheet(isPresented:$showAccount) { LedgerAccountView().environmentObject(account) }
    }
}

struct LedgerAccountView: View {
    @EnvironmentObject private var account: LedgerAccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var create = false
    @State private var nonce: String?
    @State private var showDelete = false
    @State private var showCloud = false
    @State private var showGuestExport = false
    @State private var showCurrentExport = false
    @State private var signOutPrompt = false
    @State private var linkEmail = false
    @State private var consent = false
    @State private var showPrivacy = false
    private func t(_ key: String) -> String { ledgerLocalized(key) }
    var body: some View {
        NavigationStack {
            Form {
                if !account.configured {
                    Section { Text(t("帳號服務尚未啟用，請先使用本機帳本。")) }
                }
                if let user = account.user {
                    Section(t("目前帳號")) {
                        Text(user.email ?? t("Apple 私密帳號")).textSelection(.enabled)
                        Text(t("帳目會自動保存在此裝置的帳號空間。雲端備份需主動操作，登入不代表已上傳。"))
                            .font(.footnote).foregroundStyle(.secondary)
                        if !account.verified {
                            Button(t("重新寄送驗證信")) { run { try await account.sendVerification() } }
                            Button(t("我已驗證，重新檢查")) { run { try await account.refreshVerification() } }
                        }
                        Button(t("雲端備份／還原")) { showCloud = true }.disabled(!account.verified)
                        Button(t("匯出此帳號的裝置帳本")) { showCurrentExport = true }
                    }
                    Section(t("連結登入方式")) {
                        Text(t("連結後可用兩種方式登入同一帳本。其他既有帳號不會自動合併。"))
                            .font(.footnote).foregroundStyle(.secondary)
                        if !account.appleLinked { appleButton(.link) }
                        if !account.passwordLinked {
                            Toggle(t("設定 Email 與密碼"),isOn:$linkEmail)
                            if linkEmail {
                                emailFields
                                Button(t("連結 Email 登入")) { run { try await account.linkEmail(email,password:password); password = "" } }
                            }
                        }
                    }
                    Section {
                        Button(t("登出")) { signOutPrompt = true }
                        Button(t("刪除帳號"),role:.destructive) { showDelete = true }
                    }
                } else {
                    Section(t("選擇登入方式")) {
                        Text(t("可使用 Apple，或以 Email 註冊。登入後會開啟獨立帳本；原有本機訪客資料會保留。"))
                            .font(.footnote).foregroundStyle(.secondary)
                        Toggle(t("我已閱讀隱私權政策，並同意建立帳號"),isOn:$consent)
                        Button(t("帳號與雲端隱私權政策")) { showPrivacy = true }
                        appleButton(.signIn).disabled(!consent)
                        Picker(t("Email 方式"),selection:$create) {
                            Text(t("登入")).tag(false); Text(t("註冊帳號")).tag(true)
                        }.pickerStyle(.segmented)
                        emailFields
                        if create {
                            SecureField(t("再次輸入密碼"),text:$confirmation).textContentType(.newPassword)
                        }
                        Button(t(create ? "建立帳號" : "Email 登入")) {
                            guard !create || password == confirmation else { account.error = t("兩次密碼不一致。"); return }
                            run { try await account.email(email,password:password,create:create); password = ""; confirmation = "" }
                        }.disabled(!consent)
                        Button(t("忘記密碼")) { run { try await account.resetPassword(email) } }
                    }
                }
                Section(t("原有本機資料")) {
                    Button(t("查看／匯出訪客帳本")) { showGuestExport = true }
                    Text(t("如需移入登入後的帳號，先匯出訪客 JSON，再從帳本的備份／匯入選取目前攤商匯入；不會自動搬移或刪除。"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !account.message.isEmpty { Section { Text(account.message).foregroundStyle(.green).accessibilityIdentifier("account.message") } }
                if !account.error.isEmpty { Section { Text(account.error).foregroundStyle(.red).accessibilityIdentifier("account.error") } }
                if account.busy { Section { ProgressView(t("處理中…")) } }
            }
            .disabled(account.busy)
            .navigationTitle(t("帳號與資料"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button(t("完成")) { dismiss() }.disabled(account.busy) } }
            .sheet(isPresented:$showPrivacy) { NavigationStack { LedgerPrivacyView() } }
            .sheet(isPresented:$showCloud) { LedgerCloudBackupView(account:account) }
            .sheet(isPresented:$showDelete) { deleteView }
            .sheet(isPresented:$showGuestExport) { LedgerRecoveryView(dataStore:.default()) }
            .sheet(isPresented:$showCurrentExport) { LedgerRecoveryView(dataStore:account.dataStore) }
            .confirmationDialog(t("登出前請先儲存正在編輯的帳目。"),isPresented:$signOutPrompt,titleVisibility:.visible) {
                Button(t("登出"),role:.destructive) { run { try account.signOut() } }
            }
        }
    }
    private var emailFields: some View {
        Group {
            TextField(t("Email"),text:$email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.emailAddress)
            SecureField(t("密碼（至少 8 個字元）"),text:$password).textContentType(create ? .newPassword : .password)
        }
    }
    private func appleButton(_ purpose: LedgerAccountStore.ApplePurpose) -> some View {
        SignInWithAppleButton(.continue) { request in
            do {
                let value = try LedgerAccountStore.nonce(); nonce = value
                request.requestedScopes = [.email]
                request.nonce = LedgerAccountStore.sha256(value)
            } catch { nonce = nil; account.error = LedgerAccountStore.friendly(error) }
        } onCompletion: { result in
            let value = nonce; nonce = nil
            run { try await account.completeApple(result,nonce:value,purpose:purpose); if purpose == .delete { showDelete = false } }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height:50)
        .disabled(!account.configured || account.busy)
        .accessibilityLabel(t(purpose == .delete ? "使用 Apple 驗證並刪除帳號" : purpose == .link ? "連結 Apple 登入" : "使用 Apple 登入"))
    }
    private var deleteView: some View {
        NavigationStack {
            Form {
                Section {
                    Text(t("刪除將永久移除帳號、雲端備份，以及此裝置該帳號的資料。請先匯出需要保留的帳本。訪客及其他帳號資料不受影響。"))
                    Text(t("刪除帳號不會取消 Apple 訂閱，請另至訂閱管理取消。"))
                    Link(t("管理 Apple 訂閱"),destination:URL(string:"https://apps.apple.com/account/subscriptions")!)
                }
                Section(t("重新驗證後刪除")) {
                    if account.appleLinked { appleButton(.delete) }
                    else {
                        SecureField(t("目前密碼"),text:$password).textContentType(.password)
                        Button(t("永久刪除帳號與資料"),role:.destructive) { run { try await account.deleteWithPassword(password); password = ""; showDelete = false } }
                    }
                }.disabled(account.busy)
                if !account.error.isEmpty { Text(account.error).foregroundStyle(.red) }
            }
            .navigationTitle(t("刪除帳號"))
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button(t("取消")) { showDelete = false }.disabled(account.busy) } }
            .interactiveDismissDisabled(account.busy)
        }
    }
    private func run(_ operation: @escaping () async throws -> Void) { Task { await account.perform(operation) } }
}

struct LedgerCloudBackupView: View {
    @StateObject private var model: LedgerCloudBackup
    private let account: LedgerAccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var pending: String?
    @State private var importing = false
    @State private var localSnapshot: String?
    init(account: LedgerAccountStore) { self.account = account; _model = StateObject(wrappedValue:LedgerCloudBackup(account:account)) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(ledgerLocalized("帳本會傳送至此 App 的 Firebase 雲端服務，僅供此登入帳號存取。備份包含所有攤商、配方與舊版封存；不含原始照片。請勿在共用裝置保留登入。"))
                        .font(.footnote)
                    Text(ledgerLocalized("這是主動備份與還原，不是即時雙向同步。離線仍會保存裝置帳本。"))
                }
                Section(ledgerLocalized("雲端版本")) {
                    if let head = model.head {
                        if let date = head.date { Text(date,format:.dateTime.year().month().day().hour().minute()) }
                        Text(ByteCountFormatter.string(fromByteCount:Int64(head.bytes),countStyle:.file))
                    } else { Text(ledgerLocalized("尚未讀取或尚無雲端備份。")) }
                    Button(ledgerLocalized("重新檢查雲端")) { Task { await model.run { try await model.inspect() } } }
                }
                Section {
                    Button(ledgerLocalized("將本機帳本備份到雲端")) { pending = "upload" }
                    Button(ledgerLocalized("以雲端版本還原本機")) { pending = "restore" }.disabled(model.head == nil)
                }.disabled(!model.ready || model.busy)
                Section(ledgerLocalized("完整帳號備份")) {
                    Button(ledgerLocalized("匯出完整帳號備份")) { Task { await model.run { try await model.exportSnapshot() } } }
                    Button(ledgerLocalized("匯入完整帳號備份")) { importing = true }
                    ForEach(model.recoveryFiles,id: \.self) { file in
                        Button(file.lastPathComponent) { model.recoveryExport = LedgerRecoveryExport(url:file) }
                    }
                }.disabled(model.busy || !model.ready)
                if !model.message.isEmpty { Text(model.message).foregroundStyle(.green) }
                if !model.error.isEmpty { Text(model.error).foregroundStyle(.red) }
                if model.busy { ProgressView(ledgerLocalized("處理中…")) }
                LedgerAccountBackupWeb(store:account.dataStore,model:model).frame(height:1).opacity(0).allowsHitTesting(false).accessibilityHidden(true)
            }
            .navigationTitle(ledgerLocalized("雲端備份／還原"))
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button(ledgerLocalized("完成")) { dismiss() }.disabled(model.busy) } }
            .interactiveDismissDisabled(model.busy)
            .task { model.loadRecoveryFiles(); await model.run { try await model.inspect() } }
            .confirmationDialog(ledgerLocalized(pending == "upload" ? "確認以此裝置帳本建立新的雲端備份？" : pending == "local" ? "確認以匯入備份取代此帳號的本機資料？" : "確認以雲端帳本取代此帳號的本機資料？"),isPresented:Binding(get:{pending != nil},set:{if !$0 {pending = nil}}),titleVisibility:.visible) {
                Button(ledgerLocalized("確認"),role:.destructive) {
                    let action = pending; pending = nil
                    Task { await model.run { if action == "upload" { try await model.upload() } else if action == "local", let text = localSnapshot { try await model.importSnapshot(text); localSnapshot = nil } else { try await model.restore() } } }
                }
                Button(ledgerLocalized("取消"),role:.cancel) { pending = nil }
            }
            .fileImporter(isPresented:$importing,allowedContentTypes:[.json]) { result in
                do {
                    let url = try result.get()
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf:url,options:.mappedIfSafe)
                    guard data.count <= 25_000_000, let text = String(data:data,encoding:.utf8) else { throw LedgerAccountError.message("備份資料無法讀取或檔案過大。") }
                    localSnapshot = text; pending = "local"
                } catch { model.error = error.localizedDescription }
            }
            .sheet(item:$model.recoveryExport) { item in LedgerBackupShareSheet(url:item.url,removeAfterShare:false) }
        }
    }
}
