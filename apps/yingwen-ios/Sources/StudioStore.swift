import SwiftUI
import AVFoundation

@MainActor final class StudioStore: ObservableObject {
    @Published var brief = ProductBrief()
    @Published var result: CreativeResult?
    @Published var voiceover = ""
    @Published var drafts: [StudioDraft] = []
    @Published var connected = SecureKey.read() != nil
    @Published var message: String?
    @Published var busy = false
    @Published var selectedTab = 0
    init() { loadDrafts() }
    var service: GeminiService { get throws { guard let key = SecureKey.read() else { throw StudioError.message("請先到「設定」連接 Gemini。") }; return GeminiService(key: key) } }
    func run(_ action: @escaping @MainActor () async throws -> Void) async {
        guard !busy else { return }; busy = true
        defer { busy = false }
        do { try await action() } catch is CancellationError { message = "已取消。" } catch { message = error.localizedDescription }
    }
    func generateCopy() async throws {
        guard !brief.product.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StudioError.message("請先輸入商品或服務名稱。") }
        let output = try await service.copy(brief)
        result = output; voiceover = output.voiceover
    }
    func example() {
        brief.brand = "喬鈺酥香屋"; brief.product = "紅麴豆乳雞"; brief.facts = "使用國產雞肉，主打紅麴豆乳風味。不要加上未確認的售價、優惠、地址，也不要宣稱現醃。"; brief.audience = "喜歡夜市點心、下班想吃美食的人"; brief.tone = "食慾誘惑"
    }
    func connect(_ raw: String, freeConfirmed: Bool) async throws {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 20, key.count <= 512, !key.unicodeScalars.contains(where: { $0.value < 33 || $0.value > 126 }) else { throw StudioError.message("請完整貼上 Gemini 金鑰，支援新版 AQ. 格式。") }
        guard freeConfirmed else { throw StudioError.message("請先確認 Google 專案未啟用付費帳務。") }
        try await GeminiService(key: key).verify(); try SecureKey.save(key); connected = true; message = "Gemini 已連接，可以開始創作。"
    }
    func disconnect() { SecureKey.remove(); connected = false; message = "已移除這台手機的 Gemini 金鑰。" }
    private var draftsURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("drafts.json") }
    func saveDraft() {
        drafts.insert(StudioDraft(brief: brief, result: result, voiceover: voiceover), at: 0)
        drafts = Array(drafts.prefix(50)); persistDrafts(); message = "草稿已儲存在這台 iPhone。"
    }
    func restore(_ draft: StudioDraft) { brief = draft.brief; result = draft.result; voiceover = draft.voiceover; selectedTab = 0 }
    func deleteDraft(_ id: UUID) { drafts.removeAll { $0.id == id }; persistDrafts() }
    private func loadDrafts() {
        do { if FileManager.default.fileExists(atPath: draftsURL.path) { drafts = try JSONDecoder().decode([StudioDraft].self, from: Data(contentsOf: draftsURL)) } }
        catch { message = "既有草稿暫時無法讀取，資料檔未被覆寫。" }
    }
    private func persistDrafts() {
        do { try JSONEncoder().encode(drafts).write(to: draftsURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
        catch { message = "草稿未成功儲存，請確認手機可用空間。" }
    }
    static func copyIntoDocuments(_ original: URL, prefix: String) throws -> URL {
        let access = original.startAccessingSecurityScopedResource(); defer { if access { original.stopAccessingSecurityScopedResource() } }
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent(prefix + "-" + UUID().uuidString + "." + original.pathExtension)
        try FileManager.default.copyItem(at: original, to: target); return target
    }
}
