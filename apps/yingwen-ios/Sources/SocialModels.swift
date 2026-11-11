import Foundation
import Combine

// Workflow adapted from Hao0321/claude-skill-social-post (MIT). See SocialCreditsView.
struct SocialBrief: Codable, Equatable {
    var topic = ""
    var facts = ""
    var audience = ""
    var goal = "增加互動"
    var platforms = ["Facebook"]
}

struct SocialPost: Codable, Equatable {
    var platform: String
    var hook: String
    var body: String
    var cta: String
    var hashtags: String
    var visual: String
    var fullText: String { [hook, body, cta, hashtags].filter { !$0.isEmpty }.joined(separator: "\n\n") }
}

struct SocialPlanItem: Codable, Equatable {
    var day: Int
    var topic: String
    var angle: String
    var format: String
    var cta: String
}

struct SocialAIResult: Codable {
    var voice: String
    var posts: [SocialPost]
    var plan: [SocialPlanItem]
    var notes: String
}

struct SocialSavedDraft: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var brief: SocialBrief
    // Each explicit save appends a full snapshot; older versions are never overwritten.
    var versions: [[SocialPost]]
    mutating func save(_ posts: [SocialPost]) -> Bool {
        guard versions.last != posts else { return false }
        versions.append(posts)
        return true
    }
}

struct SocialOutcome: Codable, Identifiable {
    var id = UUID()
    var postID: UUID
    var platform: String
    var title: String
    var publishedAt: Date
    var capturedAt: Date
    var impressions: Int?
    var likes: Int?
    var comments: Int?
    var shares: Int?
    var saves: Int?
    var ageBand: String {
        let hours = capturedAt.timeIntervalSince(publishedAt) / 3600
        if hours < 24 { return "未滿 24 小時" }
        if hours < 72 { return "24–72 小時" }
        if hours < 168 { return "3–7 天" }
        return "7 天以上"
    }
    var engagementRate: Double? {
        guard let impressions, impressions > 0, let likes, let comments, let shares, let saves else { return nil }
        return Double(likes + comments + shares + saves) / Double(impressions)
    }
    func comparable(to other: SocialOutcome) -> Bool { platform == other.platform && ageBand == other.ageBand }
    static func metric(_ text: String) throws -> Int? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return nil }
        guard clean.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(clean), value <= 1_000_000_000 else {
            throw StudioError.message("成效請填 0 到 10 億的整數；不知道的數字請留白。")
        }
        return value
    }
}

struct SocialWorkspace: Codable {
    var samples = ""
    var voice = ""
    var brief = SocialBrief()
    var posts: [SocialPost] = []
    var plan: [SocialPlanItem] = []
    var notes = ""
    var drafts: [SocialSavedDraft] = []
    var outcomes: [SocialOutcome] = []
    var activeDraftID: UUID?
    mutating func saveDraft() {
        guard !posts.isEmpty else { return }
        if let index = drafts.firstIndex(where: { $0.id == activeDraftID }) {
            _ = drafts[index].save(posts)
        } else {
            let draft = SocialSavedDraft(brief: brief, versions: [posts])
            drafts.insert(draft, at: 0)
            activeDraftID = draft.id
        }
    }
}

@MainActor final class SocialStudioStore: ObservableObject {
    @Published var data = SocialWorkspace()
    @Published var error: String?
    private let file: URL
    private var canSave = true
    init(file: URL = URL.documentsDirectory.appendingPathComponent("social-workspace-v1.json")) {
        self.file = file
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do { data = try JSONDecoder().decode(SocialWorkspace.self, from: Data(contentsOf: file)) }
        catch { canSave = false; self.error = "社群資料暫時無法讀取，原始檔已保留；請先關閉頁面再重試。" }
    }
    @discardableResult func persist() -> Bool {
        guard canSave else { error = "原始社群資料無法讀取，已停止覆寫以保留資料。"; return false }
        do {
            try JSONEncoder().encode(data).write(to: file, options: [.atomic, .completeFileProtection])
            error = nil
            return true
        } catch { self.error = "社群資料未能儲存：\(error.localizedDescription)"; return false }
    }
}
