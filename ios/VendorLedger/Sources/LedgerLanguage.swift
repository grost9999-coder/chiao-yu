import SwiftUI

// Interface choice is global to this device; it never changes stored ledger data.
enum LedgerLanguage {
    static let options = ["system", "zh-Hant", "zh-Hans", "en", "ja"]
    static func resolved(_ value: String) -> String {
        let raw = value == "system" ? (Locale.preferredLanguages.first ?? "zh-Hant") : value
        let code = raw.lowercased()
        if code.hasPrefix("en") { return "en" }
        if code.hasPrefix("ja") { return "ja" }
        if code.hasPrefix("zh") {
            return code.contains("hans") || code.contains("cn") || code.contains("sg") ? "zh-Hans" : "zh-Hant"
        }
        return "zh-Hant"
    }
    static func name(_ value: String) -> String {
        switch value {
        case "en": return "English"
        case "ja": return "日本語"
        case "zh-Hans": return "简体中文"
        case "zh-Hant": return "繁體中文"
        default: return ledgerLocalized("跟隨系統")
        }
    }
}

func ledgerLocalized(_ key: String) -> String {
    let code = LedgerLanguage.resolved(UserDefaults.standard.string(forKey: "ledger.language") ?? "system")
    guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return key }
    return bundle.localizedString(forKey: key, value: key, table: nil)
}

struct LedgerLanguagePicker: View {
    @AppStorage("ledger.language") private var language = "system"
    @State private var pending: String?
    var body: some View {
        HStack {
            Spacer()
            Menu {
                ForEach(LedgerLanguage.options, id: \.self) { code in
                    Button {
                        if code != language { pending = code }
                    } label: {
                        if code == language { Label(LedgerLanguage.name(code), systemImage: "checkmark") }
                        else { Text(LedgerLanguage.name(code)) }
                    }
                }
            } label: {
                Label(ledgerLocalized("語言") + " · " + LedgerLanguage.name(language), systemImage: "globe")
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(.thinMaterial)
        .confirmationDialog(ledgerLocalized("切換語言"), isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button(ledgerLocalized("切換語言")) { if let next = pending { language = next }; pending = nil }
            Button(ledgerLocalized("取消"), role: .cancel) { pending = nil }
        } message: {
            Text(ledgerLocalized("切換語言前請先儲存帳目。切換會重新載入介面，未儲存的輸入將不會保留。"))
        }
    }
}
