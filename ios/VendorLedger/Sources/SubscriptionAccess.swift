import SwiftUI
import StoreKit
import WebKit

// The App Store is the authority for trial eligibility, prices, renewal and access.
// No installation-date clock or editable UserDefaults flag unlocks paid features.
enum LedgerSubscriptionConfiguration {
    static let monthlyID = "com.qiaoyu.vendorbookpro.pro.monthly"
    static let annualID = "com.qiaoyu.vendorbookpro.pro.annual"
    static let productIDs = [monthlyID, annualID]
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

@MainActor
final class LedgerSubscriptionAccess: ObservableObject {
    @Published private(set) var hasAccess = false
    @Published private(set) var isChecking = true
    @Published private(set) var products: [Product] = []
    @Published private(set) var trialAvailable = false
    @Published var message: String?
    private var checking = false
    private var loadingProducts = false

    func refresh() async {
        guard !checking else { return }
        checking = true
        defer { checking = false; isChecking = false }
        var entitled = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  LedgerSubscriptionConfiguration.productIDs.contains(transaction.productID),
                  transaction.productType == .autoRenewable,
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded else { continue }
            // currentEntitlements also includes an active billing grace period.
            // Do not reject a grace-period entitlement by its old expiration date.
            entitled = true
        }
        hasAccess = entitled
    }

    func loadProducts() async {
        guard !loadingProducts else { return }
        loadingProducts = true
        defer { loadingProducts = false }
        do {
            let fetched = try await Product.products(for: LedgerSubscriptionConfiguration.productIDs)
            products = LedgerSubscriptionConfiguration.productIDs.compactMap { id in
                fetched.first { $0.id == id && $0.type == .autoRenewable }
            }
            var eligible = false
            for product in products {
                if let subscription = product.subscription,
                   let offer = subscription.introductoryOffer,
                   offer.paymentMode == .freeTrial,
                   offer.period.unit == .month, offer.period.value == 1,
                   await subscription.isEligibleForIntroOffer {
                    eligible = true
                }
            }
            trialAvailable = eligible
            message = products.isEmpty ? ledgerLocalized("暫時無法載入訂閱方案，請連線後重試。") : nil
        } catch {
            message = ledgerLocalized("無法連線至 App Store，請稍後重試。既有帳本仍保留在此裝置。")
        }
    }

    func observeTransactions() async {
        for await result in StoreKit.Transaction.updates {
            if Task.isCancelled { return }
            guard case .verified(let transaction) = result,
                  LedgerSubscriptionConfiguration.productIDs.contains(transaction.productID) else { continue }
            await refresh()
            await transaction.finish()
        }
    }

    func purchaseCompleted(_ result: Result<Product.PurchaseResult, Error>) async {
        switch result {
        case .success(.success(let verification)):
            guard case .verified(let transaction) = verification,
                  LedgerSubscriptionConfiguration.productIDs.contains(transaction.productID) else {
                message = ledgerLocalized("購買驗證尚未完成，請稍後恢復購買。")
                return
            }
            await refresh()
            await transaction.finish()
        case .success(.pending):
            message = ledgerLocalized("購買正等待核准，核准後會自動開通。")
        case .success(.userCancelled):
            break
        case .failure:
            message = ledgerLocalized("購買未完成，請重試或使用恢復購買。")
        @unknown default:
            break
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
            message = hasAccess ? ledgerLocalized("已恢復訂閱。") : ledgerLocalized("此 Apple 帳號目前沒有有效訂閱。")
        } catch {
            message = ledgerLocalized("恢復購買未完成，請稍後重試。")
        }
    }
}

@MainActor
struct SubscriptionRootView: View {
    @StateObject private var access = LedgerSubscriptionAccess()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPlans = false
    @AppStorage("ledger.language") private var language = "system"

    var body: some View {
        VStack(spacing: 0) {
            LedgerLanguagePicker()
            Group {
            if access.isChecking {
                VStack(spacing: 14) {
                    ProgressView()
                    Text(ledgerLocalized("正在確認訂閱…")).foregroundStyle(.secondary)
                }
            } else if access.hasAccess {
                VStack(spacing: 0) {
                    LedgerView()
                    HStack {
                        Label(ledgerLocalized("訂閱使用中"), systemImage: "checkmark.seal.fill")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(ledgerLocalized("訂閱管理")) { showPlans = true }.font(.caption)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(.thinMaterial)
                }
            } else {
                LedgerSubscriptionPlans(access: access)
            }
            }.id(language)
        }
        .environment(\.locale, Locale(identifier: LedgerLanguage.resolved(language)))
        .tint(Color(red: 0.15, green: 0.43, blue: 0.32))
        .sheet(isPresented: $showPlans) {
            NavigationStack {
                LedgerSubscriptionPlans(access: access)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(ledgerLocalized("完成")) { showPlans = false }
                        }
                    }
            }
        }
        .onChange(of: access.hasAccess) { _, active in
            if active { showPlans = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await access.refresh() } }
        }
        .task { await access.observeTransactions() }
        .task {
            await access.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                if scenePhase == .active { await access.refresh() }
            }
        }
    }
}

@MainActor
struct LedgerSubscriptionPlans: View {
    @ObservedObject var access: LedgerSubscriptionAccess
    @State private var showBackup = false
    @State private var showPrivacy = false
    @State private var showManage = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 54)).foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text(ledgerLocalized("把小生意，記清楚。"))
                    .font(.title2.bold()).multilineTextAlignment(.center)
                Text(ledgerLocalized("攤商記帳王 PRO"))
                    .font(.headline).foregroundStyle(.secondary)
                Text(ledgerLocalized("每日收支・毛利分析・庫存盤點・多攤商帳本・JSON 備份"))
                    .font(.subheadline).multilineTextAlignment(.center)
                if access.trialAvailable {
                    Text(ledgerLocalized("符合資格的新訂閱者享 1 個月免費試用"))
                        .font(.subheadline.weight(.semibold))
                        .padding(12).background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
                if !access.products.isEmpty {
                    SubscriptionStoreView(subscriptions: access.products)
                        .subscriptionStoreControlStyle(.prominentPicker)
                        .storeButton(.hidden, for: .cancellation)
                        .storeButton(.visible, for: .restorePurchases)
                        .subscriptionStorePolicyDestination(url: LedgerSubscriptionConfiguration.termsURL, for: .termsOfService)
                        .subscriptionStorePolicyDestination(for: .privacyPolicy) { LedgerPrivacyView() }
                        .onInAppPurchaseCompletion { _, result in
                            await access.purchaseCompleted(result)
                        }
                } else {
                    ProgressView(ledgerLocalized("正在取得方案與價格…"))
                    Button(ledgerLocalized("重新載入方案")) {
                        Task { await access.loadProducts() }
                    }.buttonStyle(.borderedProminent)
                }
                Text(ledgerLocalized("免費試用僅限符合資格的 Apple 帳號，且須先確認訂閱。試用結束後，按所選月繳或年繳方案自動續訂並收費。請於試用或當期結束至少 24 小時前取消，以免續訂。實際價格、試用資格與扣款日期以 App Store 確認畫面為準。"))
                    .font(.footnote).foregroundStyle(.secondary)
                if let message = access.message {
                    Text(message).font(.footnote)
                }
                HStack {
                    Button(ledgerLocalized("恢復購買")) { Task { await access.restore() } }
                    Spacer()
                    Button(ledgerLocalized("管理／取消訂閱")) { showManage = true }
                }.font(.footnote)
                Divider()
                Button(ledgerLocalized("匯出既有帳本備份")) { showBackup = true }
                    .buttonStyle(.bordered)
                Text(ledgerLocalized("訂閱到期不會刪除帳本，仍可匯出此裝置上的資料。重新安裝或更換裝置前，請先備份。"))
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button(ledgerLocalized("隱私權政策")) { showPrivacy = true }
                    Spacer()
                    Link(ledgerLocalized("使用條款"), destination: LedgerSubscriptionConfiguration.termsURL)
                }.font(.footnote)
            }
            .padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.96, green: 0.98, blue: 0.95))
        .task { await access.loadProducts() }
        .manageSubscriptionsSheet(isPresented: $showManage)
        .sheet(isPresented: $showBackup) { LedgerRecoveryView() }
        .sheet(isPresented: $showPrivacy) { NavigationStack { LedgerPrivacyView() } }
    }
}

struct LedgerPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(ledgerLocalized("攤商記帳王 PRO 隱私權政策")).font(.title2.bold())
                Text(ledgerLocalized("更新日期：2026 年 10 月 30 日"))
                Text(ledgerLocalized("帳本與儲存")).font(.headline)
                Text(ledgerLocalized("收支、庫存、資產、備忘與攤商資料儲存在此裝置的 App 資料空間。本版本沒有開發者帳號系統或自動雲端同步，也不將帳本金額傳送至開發者伺服器。移除 App 或遺失裝置可能造成資料遺失，請定期匯出備份。"))
                Text(ledgerLocalized("Apple 訂閱")).font(.headline)
                Text(ledgerLocalized("訂閱、付款、試用資格與退款由 Apple 處理。App 使用 StoreKit 取得商品、購買驗證與訂閱權益狀態。開發者不會取得你的完整付款卡號。Apple 可能依其隱私權政策處理帳號與付款資料。"))
                Text(ledgerLocalized("備份與分享")).font(.headline)
                Text(ledgerLocalized("只有在你主動匯出或分享時，帳本才會交給你選擇的檔案位置或服務。備份可能含營業與財務資訊，請妥善保管。訂閱到期仍可匯出既有資料。"))
                Text(ledgerLocalized("資料控制")).font(.headline)
                Text(ledgerLocalized("你可以在各帳本功能編輯或刪除紀錄，並自行保管或刪除已匯出的備份。本版本不提供廣告追蹤，也未整合第三方廣告或分析 SDK。支援與政策問題請使用 App Store 產品頁的 App 支援連結聯絡。"))
                Link(ledgerLocalized("Apple 隱私權政策"), destination: URL(string: "https://www.apple.com/legal/privacy/")!)
            }.padding(24).frame(maxWidth: 600)
        }.navigationTitle(ledgerLocalized("隱私權政策")).navigationBarTitleDisplayMode(.inline)
    }
}
