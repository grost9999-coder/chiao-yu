import SwiftUI

// The original persistent default store is retained across upgrades.
// StoreKit entitlement is independent of app accounts; there is no sign-in SDK.
struct LedgerLocalDataShell: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("ledger.language") private var language = "system"
    @AppStorage("ledger.backup.reminder.lastShown") private var lastReminder = 0.0
    @State private var showBackup = false
    @State private var showReminder = false

    var body: some View {
        VStack(spacing: 0) {
            SubscriptionRootView()
            HStack {
                Text(ledgerLocalized("免登入・本機儲存"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(ledgerLocalized("匯出備份")) { showBackup = true }
                    .font(.caption)
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(.thinMaterial)
        }
        .environment(\.locale, Locale(identifier: LedgerLanguage.resolved(language)))
        .sheet(isPresented: $showBackup) { LedgerRecoveryView() }
        .alert(ledgerLocalized("請定期備份帳本"), isPresented: $showReminder) {
            Button(ledgerLocalized("匯出備份")) { showBackup = true }
            Button(ledgerLocalized("稍後提醒"), role: .cancel) {}
        } message: {
            Text(ledgerLocalized("資料只在此裝置。請將各攤商 JSON 備份儲存到檔案；換機或刪除 App 前務必先備份。"))
        }
        .onAppear { checkReminder() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkReminder() }
        }
    }

    private func checkReminder() {
        guard !LedgerDemo.isEnabled else { return }
        let now = Date().timeIntervalSince1970
        // First launch starts the reminder interval. This is never a claim
        // that a backup was saved: only the user chooses the destination.
        if lastReminder == 0 { lastReminder = now }
        else if now - lastReminder >= 7 * 24 * 60 * 60, !showBackup {
            lastReminder = now
            showReminder = true
        }
    }
}
