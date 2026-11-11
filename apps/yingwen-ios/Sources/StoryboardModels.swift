import Foundation
import Combine

struct ShotScript: Codable, Equatable {
    var number: Int
    var visual: String
    var camera: String
    var caption: String
    var narration: String
    var prompt: String
}

struct ShotScriptResult: Codable {
    var title: String
    var continuity: String
    var shots: [ShotScript]
}

struct ShotClip: Codable, Identifiable {
    var id = UUID()
    var filename: String
    var prompt: String
    var seconds: Int
    var portrait: Bool
    var date = Date()
    var url: URL { URL.documentsDirectory.appendingPathComponent("Exports").appendingPathComponent(filename) }
    func matches(prompt: String, seconds: Int, portrait: Bool) -> Bool {
        self.prompt == prompt && self.seconds == seconds && self.portrait == portrait && FileManager.default.fileExists(atPath: url.path)
    }
}

struct FilmShot: Codable, Identifiable {
    var id = UUID()
    var script: ShotScript
    var seconds: Int
    var clips: [ShotClip] = []
    var lastError: String?
}

struct FilmProject: Codable, Identifiable {
    var id = UUID()
    var title: String
    var continuity: String
    var portrait: Bool
    var shots: [FilmShot]
    func prompt(for shot: FilmShot) -> String {
        [continuity, shot.script.prompt].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: ". ")
    }
    func currentClip(for shot: FilmShot) -> ShotClip? {
        shot.clips.last { $0.matches(prompt: prompt(for: shot), seconds: shot.seconds, portrait: portrait) }
    }
    var pendingIDs: [UUID] { shots.filter { currentClip(for: $0) == nil }.map(\.id) }
}

@MainActor final class StoryboardStore: ObservableObject {
    @Published var projects: [FilmProject] = []
    @Published var activeID: UUID?
    @Published var busy = false
    @Published var status = ""
    @Published var error: String?
    private var writable = true
    private let file = URL.documentsDirectory.appendingPathComponent("film-storyboards-v1.json")
    init() {
        if FileManager.default.fileExists(atPath: file.path) {
            do { projects = try JSONDecoder().decode([FilmProject].self, from: Data(contentsOf: file)) }
            catch { writable = false; self.error = "分鏡資料無法讀取，已保留原檔並停止覆寫，請關閉頁面後重試。" }
        }
        activeID = projects.first?.id
    }
    @discardableResult func save() -> Bool {
        guard writable else { error = "分鏡原檔無法讀取，已停止覆寫。"; return false }
        do { try JSONEncoder().encode(projects).write(to: file, options: [.atomic, .completeFileProtection]); return true }
        catch { self.error = "分鏡儲存失敗：\(error.localizedDescription)"; return false }
    }
    func add(_ result: ShotScriptResult, seconds: Int, portrait: Bool) {
        let project = FilmProject(title: result.title, continuity: result.continuity, portrait: portrait,
                                  shots: result.shots.sorted { $0.number < $1.number }.map { FilmShot(script: $0, seconds: seconds) })
        projects.insert(project, at: 0); activeID = project.id; save()
    }
    // Each success is saved immediately. Stop on quota/error instead of submitting the remaining shots.
    func generate(projectID: UUID, shotIDs: [UUID]) async {
        guard !busy, !shotIDs.isEmpty, writable else { return }
        busy = true
        defer { busy = false }
        let token = SecureKey.read(account: "huggingface-free") ?? ""
        for (position, id) in shotIDs.enumerated() {
            guard let p = projects.firstIndex(where: { $0.id == projectID }), let s = projects[p].shots.firstIndex(where: { $0.id == id }) else { return }
            let project = projects[p], shot = project.shots[s], prompt = project.prompt(for: shot)
            status = "正在排隊／生成第 \(s + 1) 鏡（本次 \(position + 1)/\(shotIDs.count)）…"
            do {
                try Task.checkCancellation()
                let url = try await FreeVideoService(token: token).generateTextToVideo(prompt: prompt, seconds: shot.seconds, portrait: project.portrait)
                // Keep a returned clip even if cancellation arrived as download finished.
                projects[p].shots[s].clips.append(ShotClip(filename: url.lastPathComponent, prompt: prompt, seconds: shot.seconds, portrait: project.portrait))
                projects[p].shots[s].lastError = nil
                guard save() else { status = "片段已下載，但進度未能儲存；請先處理儲存錯誤。"; return }
                try Task.checkCancellation()
            } catch {
                let text = Task.isCancelled ? "已停止等待，已完成片段仍保留。" : error.localizedDescription
                projects[p].shots[s].lastError = text
                save(); status = text
                return
            }
        }
        status = "本次片段已完成，可逐鏡預覽或合併。"
    }
}
