import SwiftUI
import UIKit

struct SocialStudioView: View {
    @EnvironmentObject private var studio: StudioStore
    @StateObject private var social = SocialStudioStore()
    @State private var section = "貼文"
    @State private var authorized = false
    @State private var comment = ""
    @State private var replies: [SocialPost] = []
    @State private var showOutcome = false
    @State private var saved = false
    private let platforms = ["Facebook", "Instagram", "Threads", "X", "LINE"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("把你的口吻，變成持續創作的習慣").font(.title3.bold())
                Text("先填事實，再產出草稿。檢查後自行複製或分享，不會自動發布。AI 功能使用已連接的 Gemini 額度。").font(.subheadline).foregroundStyle(.secondary)
                Picker("社群工具", selection: $section) {
                    ForEach(["口吻", "貼文", "計畫", "成效", "回覆"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented)
                if saved { Text("已儲存到手機").font(.footnote).foregroundStyle(.secondary) }
                switch section {
                case "口吻": voiceSection
                case "計畫": planSection
                case "成效": outcomeSection
                case "回覆": replySection
                default: draftSection
                }
                NavigationLink("功能來源與授權") { SocialCreditsView() }.font(.footnote)
            }.padding()
        }
        .disabled(studio.busy)
        .background(Color.studioBackground)
        .navigationTitle("社群企劃室").navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively).studioKeyboardControls()
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("儲存") { save() } } }
        .onDisappear { social.persist() }
        .sheet(isPresented: $showOutcome) { SocialOutcomeForm(social: social) }
        .alert("社群資料", isPresented: Binding(get: { social.error != nil }, set: { if !$0 { social.error = nil } })) {
            Button("知道了") { social.error = nil }
        } message: { Text(social.error ?? "") }
    }

    private var voiceSection: some View {
        StudioCard("我的口吻卡", icon: "person.text.rectangle") {
            StudioField(title: "貼上自己寫過的 3–10 篇貼文（最多 12000 字）", text: $social.data.samples, multiline: true)
            Text("範例先存於這台手機。只有按下「分析口吻」時會把範例傳給 Google；之後生成只使用口吻卡與當次 brief，不重送範例。請先移除私人或客戶資料。").font(.footnote).foregroundStyle(.secondary)
            Toggle("這些是我自己或已獲授權使用的文字，我同意送交 Gemini 分析", isOn: $authorized)
            BusyButton(title: "分析口吻", busy: studio.busy) { generate("voice") }
                .disabled(!authorized || social.data.samples.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            StudioField(title: "口吻速查卡（可直接手寫或修改）", text: $social.data.voice, multiline: true)
            Button("清除手機上的原始範例", role: .destructive) { social.data.samples = ""; social.persist() }
            Text("刪除本機範例不會撤回已送交 Google 的資料；AI 使用依 Google 條款處理。").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var briefFields: some View {
        Group {
            StudioField(title: "這次想說什麼？", text: $social.data.brief.topic)
            StudioField(title: "已確認的事實、活動與限制", text: $social.data.brief.facts, multiline: true)
            StudioField(title: "讀者是誰？", text: $social.data.brief.audience)
            Picker("目的", selection: $social.data.brief.goal) {
                ForEach(["增加互動", "建立信任", "介紹商品", "引導詢問"], id: \.self) { Text($0) }
            }
            ForEach(platforms, id: \.self) { platform in
                Toggle(platform, isOn: Binding(get: { social.data.brief.platforms.contains(platform) }, set: { value in
                    if value { if !social.data.brief.platforms.contains(platform) { social.data.brief.platforms.append(platform) } }
                    else { social.data.brief.platforms.removeAll { $0 == platform } }
                }))
            }
            Text(social.data.voice.isEmpty ? "尚未建立口吻卡，會使用自然繁體中文。可到「口吻」手寫或學習。" : "將使用你儲存的口吻卡。").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var draftSection: some View {
        VStack(spacing: 18) {
            StudioCard("內容 brief", icon: "square.and.pencil") {
                briefFields
                Button("帶入文案頁的商品資料") {
                    social.data.brief.topic = studio.brief.product
                    social.data.brief.facts = [studio.brief.brand, studio.brief.facts].filter { !$0.isEmpty }.joined(separator: "\n")
                    social.data.brief.audience = studio.brief.audience
                }
                BusyButton(title: "生成分平台草稿", busy: studio.busy) { generate("draft") }
                    .disabled(social.data.brief.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || social.data.brief.platforms.isEmpty)
                Button("建立空白草稿・自行撰寫") {
                    social.data.saveDraft()
                    social.data.activeDraftID = nil
                    social.data.posts = social.data.brief.platforms.map {
                        SocialPost(platform: $0, hook: "", body: "", cta: "", hashtags: "", visual: "")
                    }
                    social.data.saveDraft()
                    social.persist()
                }.disabled(social.data.brief.platforms.isEmpty)
            }
            ForEach(social.data.posts.indices, id: \.self) { index in
                StudioCard(social.data.posts[index].platform, icon: "text.bubble") {
                    StudioField(title: "開頭", text: $social.data.posts[index].hook)
                    StudioField(title: "內文", text: $social.data.posts[index].body, multiline: true)
                    StudioField(title: "行動呼籲", text: $social.data.posts[index].cta)
                    StudioField(title: "標籤", text: $social.data.posts[index].hashtags)
                    StudioField(title: "配圖／拍攝建議", text: $social.data.posts[index].visual)
                    HStack {
                        Button("複製貼文") { UIPasteboard.general.string = social.data.posts[index].fullText; StudioKeyboard.dismiss() }
                        ShareLink(item: social.data.posts[index].fullText) { Label("分享", systemImage: "square.and.arrow.up") }
                    }
                }
            }
            if !social.data.notes.isEmpty { Text(social.data.notes).font(.callout).foregroundStyle(.secondary) }
            if !social.data.posts.isEmpty { Button("儲存草稿版本") { save() }.buttonStyle(.borderedProminent) }
            if !social.data.drafts.isEmpty {
                StudioCard("社群草稿與修改紀錄", icon: "clock.arrow.circlepath") {
                    ForEach(social.data.drafts) { draft in
                        DisclosureGroup("\(draft.brief.topic)・\(draft.versions.count) 個版本") {
                            ForEach(draft.versions.indices.reversed(), id: \.self) { version in
                                Button("載入第 \(version + 1) 版") {
                                    social.data.brief = draft.brief
                                    social.data.posts = draft.versions[version]
                                    social.data.activeDraftID = draft.id
                                    social.persist()
                                }
                            }
                            Button("刪除此草稿紀錄", role: .destructive) {
                                social.data.drafts.removeAll { $0.id == draft.id }
                                if social.data.activeDraftID == draft.id { social.data.activeDraftID = nil }
                                social.persist()
                            }
                        }
                    }
                }
            }
        }
    }

    private var planSection: some View {
        VStack(spacing: 18) {
            StudioCard("七日內容計畫", icon: "calendar") {
                Text("沿用「貼文」頁的主題、事實、讀者與目的。每天是一個創作方向，沒有自動排程發布。")
                Text("目前主題：\(social.data.brief.topic.isEmpty ? "請先到貼文填寫" : social.data.brief.topic)").font(.subheadline)
                BusyButton(title: "規劃七天內容", busy: studio.busy) { generate("plan") }
                    .disabled(social.data.brief.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ForEach(social.data.plan.sorted { $0.day < $1.day }, id: \.day) { item in
                StudioCard("第 \(item.day) 天・\(item.topic)", icon: "lightbulb") {
                    Text(item.angle)
                    Text("形式：\(item.format)\n行動呼籲：\(item.cta)").foregroundStyle(.secondary)
                    Button("以這個方向寫草稿") {
                        social.data.brief.topic = item.topic + "\n" + item.angle + "\n" + item.cta
                        section = "貼文"
                    }
                }
            }
        }
    }

    private var outcomeSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("手動記錄真實數字，留白代表未知。每次新增都是獨立觀察，不覆寫先前數據。只比較同平台、相同發布時間區間；成效差異不能證明因果。").font(.subheadline)
            Button("新增成效快照") { showOutcome = true }.buttonStyle(.borderedProminent)
            SocialOutcomeSummary(outcomes: social.data.outcomes)
            ForEach(social.data.outcomes.reversed()) { outcome in
                StudioCard(outcome.title, icon: "chart.bar") {
                    Text("\(outcome.platform)・\(outcome.ageBand)").font(.headline)
                    Text("發布：\(outcome.publishedAt.formatted())\n觀察：\(outcome.capturedAt.formatted())").font(.caption)
                    Text("曝光 \(metric(outcome.impressions))｜讚 \(metric(outcome.likes))｜留言 \(metric(outcome.comments))｜分享 \(metric(outcome.shares))｜收藏 \(metric(outcome.saves))")
                    if let rate = outcome.engagementRate { Text("互動／曝光：\(rate.formatted(.percent.precision(.fractionLength(1))))") }
                    else { Text("互動率：資料不足（需要曝光與四項互動數）").foregroundStyle(.secondary) }
                }
            }
        }
    }

    private var replySection: some View {
        StudioCard("留言回覆草稿", icon: "bubble.left.and.bubble.right") {
            StudioField(title: "貼上想回覆的留言（先移除私人資料）", text: $comment, multiline: true)
            Text("按下生成會把留言、口吻卡與 brief 傳給 Gemini。結果先由你審閱，再自行貼回原平台。沒有登入社群帳號或自動回覆。").font(.footnote).foregroundStyle(.secondary)
            BusyButton(title: "生成三種回覆", busy: studio.busy) { generate("reply") }
                .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ForEach(replies.indices, id: \.self) { index in
                Text(replies[index].hook).font(.headline)
                StudioField(title: "回覆內容", text: $replies[index].body, multiline: true)
                Button("複製回覆") { UIPasteboard.general.string = replies[index].body; StudioKeyboard.dismiss() }
            }
        }
    }

    private func metric(_ value: Int?) -> String { value.map(String.init) ?? "未知" }
    private func save() {
        StudioKeyboard.dismiss()
        social.data.saveDraft()
        saved = social.persist()
    }
    private func generate(_ mode: String) {
        StudioKeyboard.dismiss()
        let brief = social.data.brief, voice = social.data.voice, samples = social.data.samples, inputComment = comment
        Task { await studio.run {
            let result = try await studio.service.social(mode: mode, brief: brief, voice: voice, samples: mode == "voice" ? samples : "", comment: inputComment)
            switch mode {
            case "voice": social.data.voice = result.voice
            case "plan": social.data.plan = result.plan
            case "reply": replies = result.posts
            default:
                // Preserve edits to the preceding generated set before opening a new set.
                social.data.saveDraft()
                social.data.activeDraftID = nil
                social.data.brief = brief
                social.data.posts = result.posts
                social.data.saveDraft()
            }
            social.data.notes = result.notes
            social.persist()
        } }
    }
}

private struct SocialOutcomeSummary: View {
    let outcomes: [SocialOutcome]
    private var groups: [(String, [SocialOutcome])] {
        let grouped = Dictionary(grouping: outcomes) { $0.platform + "・" + $0.ageBand }
        return grouped.keys.sorted().map { key in
            // Multiple captures of one post must not inflate the sample count.
            let latest = Dictionary(grouping: grouped[key]!, by: \.postID).values.compactMap { $0.max { $0.capturedAt < $1.capturedAt } }
            return (key, latest)
        }
    }
    var body: some View {
        StudioCard("同平台觀察", icon: "magnifyingglass") {
            if groups.isEmpty { Text("記錄後會依平台與發布時間區間整理。") }
            ForEach(groups, id: \.0) { group in
                Text("\(group.0)：\(group.1.count) 篇不同貼文").font(.headline)
                let rates = group.1.compactMap(\.engagementRate)
                if rates.count >= 3 {
                    Text("完整數據 \(rates.count) 篇；平均互動／曝光 \((rates.reduce(0, +) / Double(rates.count)).formatted(.percent.precision(.fractionLength(1))))。只供觀察，下一次可固定題材、只調整開頭做小型實驗。")
                } else { Text("完整數據不足 3 篇，先累積樣本，不推斷最佳內容或發文時間。").foregroundStyle(.secondary) }
            }
        }
    }
}

private struct SocialOutcomeForm: View {
    @ObservedObject var social: SocialStudioStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected = "new"
    @State private var platform = "Facebook"
    @State private var title = ""
    @State private var published = Date()
    @State private var captured = Date()
    @State private var metrics = Array(repeating: "", count: 5)
    @State private var error: String?
    private var existing: [SocialOutcome] {
        Dictionary(grouping: social.data.outcomes, by: \.postID).values.compactMap { $0.max { $0.capturedAt < $1.capturedAt } }.sorted { $0.title < $1.title }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("貼文身份") {
                    Picker("記錄對象", selection: $selected) {
                        Text("新貼文").tag("new")
                        ForEach(existing) { item in Text("\(item.platform)・\(item.title)").tag(item.postID.uuidString) }
                    }.onChange(of: selected) { _, value in
                        if let item = existing.first(where: { $0.postID.uuidString == value }) {
                            title = item.title; platform = item.platform; published = item.publishedAt
                        }
                    }
                    TextField("貼文標題或辨識名稱", text: $title).disabled(selected != "new")
                    Picker("平台", selection: $platform) { ForEach(["Facebook", "Instagram", "Threads", "X", "LINE"], id: \.self) { Text($0) } }.disabled(selected != "new")
                    DatePicker("實際發布時間", selection: $published, in: ...Date()).disabled(selected != "new")
                    DatePicker("數據觀察時間", selection: $captured, in: ...Date())
                }
                Section("真實成效・未知請留白") {
                    ForEach(Array(["曝光次數", "讚", "留言", "分享", "收藏"].enumerated()), id: \.offset) { index, label in
                        TextField(label, text: $metrics[index]).keyboardType(.numberPad)
                    }
                    Text("曝光使用平台顯示的 impressions，請勿以觀看次數或觸及人數代替。平台未提供的項目留白。")
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("儲存新快照") { record() }
            }.navigationTitle("成效快照").studioKeyboardControls()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
    private func record() {
        do {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StudioError.message("請填寫貼文名稱。") }
            guard captured >= published else { throw StudioError.message("觀察時間不能早於發布時間。") }
            let values = try metrics.map { try SocialOutcome.metric($0) }
            social.data.outcomes.append(SocialOutcome(postID: UUID(uuidString: selected) ?? UUID(), platform: platform, title: title,
                publishedAt: published, capturedAt: captured, impressions: values[0], likes: values[1], comments: values[2], shares: values[3], saves: values[4]))
            if social.persist() { dismiss() }
            else {
                social.data.outcomes.removeLast()
                error = social.error
            }
        } catch { self.error = error.localizedDescription }
    }
}
