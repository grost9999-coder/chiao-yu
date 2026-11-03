import Foundation

struct ProductBrief: Codable, Equatable {
    var brand = ""
    var product = ""
    var facts = ""
    var audience = ""
    var platform = "Facebook 貼文"
    var tone = "親切自然"
    var goal = "吸引顧客購買"
    var duration = 15
}

struct CopyVariant: Codable, Identifiable, Equatable {
    var id: UUID
    var angle: String
    var title: String
    var body: String
    var cta: String
    var hashtags: [String]

    init(id: UUID = UUID(), angle: String, title: String, body: String, cta: String, hashtags: [String]) {
        self.id = id
        self.angle = angle
        self.title = title
        self.body = body
        self.cta = cta
        self.hashtags = hashtags
    }

    private enum CodingKeys: String, CodingKey { case id, angle, title, body, cta, hashtags }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        angle = try values.decode(String.self, forKey: .angle)
        title = try values.decode(String.self, forKey: .title)
        body = try values.decode(String.self, forKey: .body)
        cta = try values.decode(String.self, forKey: .cta)
        hashtags = try values.decode([String].self, forKey: .hashtags)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(angle, forKey: .angle)
        try values.encode(title, forKey: .title)
        try values.encode(body, forKey: .body)
        try values.encode(cta, forKey: .cta)
        try values.encode(hashtags, forKey: .hashtags)
    }

    var fullText: String {
        [title, body, cta, hashtags.map { $0.hasPrefix("#") ? $0 : "#" + $0 }.joined(separator: " ")]
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

struct StoryScene: Codable, Identifiable, Equatable {
    var id: String { caption + visual }
    var visual: String
    var caption: String
}

struct CreativeResult: Codable, Equatable {
    var variants: [CopyVariant]
    var voiceover: String
    var scenes: [StoryScene]
    var videoPrompt: String
}

struct Caption: Codable, Equatable, Identifiable {
    var id: String { "\(start)-\(end)-\(text)" }
    var start: Double
    var end: Double
    var text: String
}

struct Transcript: Codable { var text: String; var segments: [Caption] }
struct Highlight: Codable { var start: Double; var end: Double; var reason: String }

struct StudioDraftSnapshot: Codable, Equatable {
    var brief: ProductBrief
    var result: CreativeResult?
    var voiceover: String
    var manualText: String
}

struct StudioDraftRevision: Codable, Identifiable, Equatable {
    var id: Int { version }
    var version: Int
    var savedAt: Date
    var snapshot: StudioDraftSnapshot
}

struct StudioDraft: Codable, Identifiable {
    var id = UUID()
    var createdAt = Date()
    var brief: ProductBrief
    var result: CreativeResult?
    var voiceover: String
    // Optional new keys keep older drafts.json files readable.
    var manualText: String? = nil
    var updatedAt: Date? = nil
    var revisions: [StudioDraftRevision]? = nil

    var currentSnapshot: StudioDraftSnapshot {
        StudioDraftSnapshot(brief: brief, result: result, voiceover: voiceover, manualText: manualText ?? "")
    }

    var lastSavedAt: Date { updatedAt ?? createdAt }

    var revisionHistory: [StudioDraftRevision] {
        if let revisions, !revisions.isEmpty { return revisions }
        return [StudioDraftRevision(version: 1, savedAt: createdAt, snapshot: currentSnapshot)]
    }

    @discardableResult
    mutating func recordVersion(_ snapshot: StudioDraftSnapshot, at date: Date = Date()) -> Int? {
        guard snapshot != currentSnapshot else { return nil }
        var history = revisions ?? [StudioDraftRevision(version: 1, savedAt: createdAt, snapshot: currentSnapshot)]
        let nextVersion = (history.map(\.version).max() ?? 0) + 1
        history.append(StudioDraftRevision(version: nextVersion, savedAt: date, snapshot: snapshot))
        if history.count > 30 { history = Array(history.suffix(30)) }
        brief = snapshot.brief
        result = snapshot.result
        voiceover = snapshot.voiceover
        manualText = snapshot.manualText
        updatedAt = date
        revisions = history
        return nextVersion
    }
}

enum StudioError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}

enum AspectRatio: String, CaseIterable, Identifiable {
    case portrait = "9:16", square = "1:1", landscape = "16:9"
    var id: String { rawValue }
    var width: Int { self == .landscape ? 1280 : 720 }
    var height: Int { self == .portrait ? 1280 : 720 }
}

enum SubtitleFormat {
    static func stamp(_ seconds: Double) -> String {
        let n = Int((max(0, seconds) * 1000).rounded())
        return String(format: "%02d:%02d:%02d,%03d", n / 3600000, n / 60000 % 60, n / 1000 % 60, n % 1000)
    }
    static func srt(_ captions: [Caption]) -> String {
        captions.enumerated().map { i, c in "\(i + 1)\n\(stamp(c.start)) --> \(stamp(c.end))\n\(c.text)" }.joined(separator: "\n\n")
    }
    static func parse(_ text: String) throws -> [Caption] {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        let normalized = text.replacingOccurrences(of: "\r", with: "")
        let regex = try NSRegularExpression(pattern: #"(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})"#)
        let blocks = normalized.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return try blocks.map { block in
            let rows = block.components(separatedBy: "\n")
            guard let index = rows.firstIndex(where: { $0.contains("-->") }) else { throw StudioError.message("字幕缺少時間軸，請使用 SRT 格式。") }
            let row = rows[index] as NSString
            guard let match = regex.firstMatch(in: rows[index], range: NSRange(location: 0, length: row.length)) else { throw StudioError.message("字幕時間格式有誤，請使用 00:00:00,000。") }
            func number(_ i: Int) -> Double { Double(row.substring(with: match.range(at: i))) ?? 0 }
            for i in [2, 3, 6, 7] { if number(i) >= 60 { throw StudioError.message("字幕的分鐘與秒數必須小於 60。") } }
            let start = number(1) * 3600 + number(2) * 60 + number(3) + number(4) / 1000
            let end = number(5) * 3600 + number(6) * 60 + number(7) + number(8) / 1000
            let caption = rows.dropFirst(index + 1).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard end > start, !caption.isEmpty else { throw StudioError.message("每段字幕需有文字，結束時間需晚於開始時間。") }
            return Caption(start: start, end: end, text: caption)
        }.sorted { $0.start < $1.start }
    }
    static func clipped(_ captions: [Caption], start: Double, end: Double) -> [Caption] {
        captions.filter { $0.end > start && $0.start < end }.map {
            Caption(start: max(0, $0.start - start), end: min(end - start, $0.end - start), text: $0.text)
        }.filter { $0.end > $0.start }
    }
    static func distributed(_ text: String, duration: Double) -> [Caption] {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let count = lines.reduce(0.0) { $0 + Double(max(5, $1.count)) }
        var time = 0.0
        return lines.map { line in
            let start = time
            time += Double(max(5, line.count)) / max(1, count) * duration
            return Caption(start: start, end: time, text: line)
        }
    }
}
