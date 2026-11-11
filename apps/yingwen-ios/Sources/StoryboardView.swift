import SwiftUI

struct StoryboardView: View {
    @EnvironmentObject private var studio: StudioStore
    @StateObject private var board = StoryboardStore()
    @State private var brief: SocialBrief
    let voice: String
    @State private var count = 3
    @State private var seconds = 4
    @State private var portrait = true
    @State private var consent = false
    @State private var burnCaptions = true
    @State private var task: Task<Void, Never>?
    @State private var preview: VideoPreviewItem?
    @State private var merged: URL?
    @State private var exporting = false
    init(brief: SocialBrief = SocialBrief(), voice: String = "") {
        _brief = State(initialValue: brief); self.voice = voice
    }
    private var working: Bool { board.busy || studio.busy || exporting }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StudioCard("先寫分鏡，再逐鏡成片", icon: "film.stack") {
                    StudioField(title: "短片主題／故事大綱", text: $brief.topic, multiline: true)
                    StudioField(title: "確認過的商品事實與限制", text: $brief.facts, multiline: true)
                    StudioField(title: "觀眾", text: $brief.audience)
                    Stepper("分成 \(count) 鏡", value: $count, in: 2...8)
                    Picker("每鏡長度", selection: $seconds) { ForEach([2, 4, 6, 8], id: \.self) { Text("\($0) 秒") } }
                    Toggle("直式 9:16（關閉為橫式）", isOn: $portrait)
                    Text("預計 \(count * seconds) 秒。每鏡獨立生成；可分段重試，免費額度不足時會停止並保留已完成片段。角色與商品外觀可能在不同鏡頭間變化。").font(.footnote).foregroundStyle(.secondary)
                    BusyButton(title: "AI 產生分鏡腳本", busy: studio.busy) { createScript() }
                        .disabled(brief.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("建立空白分鏡・自行填寫") {
                        let result = ShotScriptResult(title: brief.topic.isEmpty ? "手寫分鏡" : brief.topic, continuity: "",
                            shots: (1...count).map { ShotScript(number: $0, visual: "", camera: "", caption: "", narration: "", prompt: "") })
                        board.add(result, seconds: seconds, portrait: portrait)
                    }
                    Text("AI 腳本使用 Gemini 額度；生成後先檢查，不會立刻送出影片生成。手寫分鏡不需 API。").font(.footnote).foregroundStyle(.secondary)
                }.disabled(working)

                if !board.projects.isEmpty {
                    Picker("分鏡專案", selection: Binding(get: { board.activeID ?? board.projects[0].id }, set: { board.activeID = $0 })) {
                        ForEach(board.projects) { Text($0.title).tag($0.id) }
                    }.disabled(working)
                }
                if let index = board.projects.firstIndex(where: { $0.id == board.activeID }) {
                    projectView(index)
                }
                if !board.status.isEmpty { Text(board.status).font(.callout).foregroundStyle(.secondary) }
                if board.busy {
                    Button("停止後續生成", role: .cancel) { task?.cancel() }
                    Text("停止等待不保證中止雲端已開始的運算。完成的片段會保留在手機。").font(.footnote)
                }
                if let merged {
                    StudioCard("上次合併成品", icon: "play.rectangle") {
                        Button("預覽合併影片") { preview = VideoPreviewItem(url: merged) }
                        ShareLink(item: merged) { Label("分享／儲存檔案", systemImage: "square.and.arrow.up") }
                        Button("存到相簿") { Task { await studio.run { try await VideoMaker.saveToPhotos(merged); studio.message = "已儲存到相簿。" } } }
                    }
                }
                NavigationLink("免費服務與 Hugging Face 權杖設定") { FreeVideoView() }
            }.padding()
        }.background(Color.studioBackground)
        .navigationTitle("分鏡與分段影片").navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively).studioKeyboardControls()
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("儲存") { if board.save() { board.status = "分鏡已儲存到手機。" }; StudioKeyboard.dismiss() }.disabled(working) } }
        .onDisappear { task?.cancel(); board.save() }
        .sheet(item: $preview) { VideoPreviewSheet(item: $0) }
        .alert("分鏡資料", isPresented: Binding(get: { board.error != nil }, set: { if !$0 { board.error = nil } })) {
            Button("知道了") { board.error = nil }
        } message: { Text(board.error ?? "") }
    }

    @ViewBuilder private func projectView(_ index: Int) -> some View {
        let project = board.projects[index]
        StudioCard("\(project.title)・\(project.shots.count) 鏡", icon: "rectangle.stack") {
            StudioField(title: "全片共同外觀、場景與風格（會加入每鏡描述）", text: $board.projects[index].continuity, multiline: true)
            Toggle("直式影片", isOn: $board.projects[index].portrait)
            Toggle("我同意把共同描述與每鏡提示詞傳給 Hugging Face 社群服務生成", isOn: $consent)
            Text("單段約 2–8 秒，低解析度；批次依序處理，不同時佔用免費 GPU。字幕與配音稿不會要求模型畫在畫面上；配音稿先供你錄製，這個流程不會自動合成配音。").font(.footnote).foregroundStyle(.secondary)
            BusyButton(title: "依序生成未完成片段（\(project.pendingIDs.count) 鏡）", busy: board.busy) { generate(projectID: project.id, ids: project.pendingIDs) }
                .disabled(!consent || project.pendingIDs.isEmpty)
            Toggle("合併時加上每鏡字幕", isOn: $burnCaptions)
            BusyButton(title: "依分鏡順序合併影片", busy: exporting) { merge(project) }
                .disabled(!project.pendingIDs.isEmpty)
        }.disabled(working)
        ForEach(project.shots.indices, id: \.self) { shotIndex in
            let shot = project.shots[shotIndex]
            StudioCard("第 \(shotIndex + 1) 鏡", icon: "film") {
                StudioField(title: "畫面", text: $board.projects[index].shots[shotIndex].script.visual, multiline: true)
                StudioField(title: "運鏡", text: $board.projects[index].shots[shotIndex].script.camera)
                StudioField(title: "字幕", text: $board.projects[index].shots[shotIndex].script.caption)
                StudioField(title: "配音稿", text: $board.projects[index].shots[shotIndex].script.narration, multiline: true)
                StudioField(title: "實際送出的影片提示詞（修改畫面或運鏡時也請更新此欄）", text: $board.projects[index].shots[shotIndex].script.prompt, multiline: true)
                Picker("片段秒數", selection: $board.projects[index].shots[shotIndex].seconds) { ForEach([2, 4, 6, 8], id: \.self) { Text("\($0) 秒") } }
                Text(project.currentClip(for: shot) == nil ? "尚未完成目前版本" : "目前版本已完成").font(.subheadline).foregroundStyle(.secondary)
                Button(shot.clips.isEmpty ? "只生成這一鏡" : "重新生成這一鏡・保留舊片段") { generate(projectID: project.id, ids: [shot.id]) }
                    .buttonStyle(.borderedProminent).disabled(!consent)
                if let error = shot.lastError { Text(error).foregroundStyle(.secondary).font(.footnote) }
                ForEach(Array(shot.clips.enumerated()), id: \.element.id) { clipIndex, clip in
                    HStack {
                        Button("預覽片段第 \(clipIndex + 1) 版") { preview = VideoPreviewItem(url: clip.url) }
                        ShareLink(item: clip.url) { Image(systemName: "square.and.arrow.up") }
                    }
                    if !clip.matches(prompt: project.prompt(for: shot), seconds: shot.seconds, portrait: project.portrait) {
                        Text("這是舊描述／秒數的版本，不納入目前合併。").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.disabled(working)
        }
    }
    private func createScript() {
        StudioKeyboard.dismiss()
        let source = brief, number = count, duration = seconds, vertical = portrait
        Task { await studio.run {
            let result = try await studio.service.storyboard(brief: source, voice: voice, count: number, seconds: duration)
            board.add(result, seconds: duration, portrait: vertical)
        } }
    }
    private func generate(projectID: UUID, ids: [UUID]) {
        guard !working, consent, board.save() else { return }
        guard let project = board.projects.first(where: { $0.id == projectID }), project.shots.filter({ ids.contains($0.id) }).allSatisfy({
            !$0.script.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && project.prompt(for: $0).count <= 2000
        }) else { board.error = "請先填寫每一鏡的影片提示詞；加上共同描述後限 2000 字。"; return }
        StudioKeyboard.dismiss()
        task = Task { await board.generate(projectID: projectID, shotIDs: ids); task = nil }
    }
    private func merge(_ project: FilmProject) {
        guard !working else { return }
        exporting = true
        StudioKeyboard.dismiss()
        Task { @MainActor in
            defer { exporting = false }
            do { merged = try await VideoMaker.storyboardMovie(project, captions: burnCaptions); board.status = "合併完成，已保存在手機。" }
            catch { board.error = error.localizedDescription }
        }
    }
}
