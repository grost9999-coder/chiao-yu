import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: StudioStore
    @State private var inputKey = ""
    @State private var confirmed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(store.connected ? "Gemini 已連接" : "尚未連接 Gemini", systemImage: store.connected ? "checkmark.shield.fill" : "key.fill").foregroundStyle(Color.studioPurple)
                    Link("1. 到 Google AI Studio 建立金鑰", destination: URL(string: "https://aistudio.google.com/api-keys")!)
                    Text("使用未啟用付費帳務的 Google 專案。免費額度依帳戶、地區與模型而定；App不會自動改用其他付費服務。").font(.subheadline).foregroundStyle(.secondary)
                    SecureField("2. 在這裡貼上 Gemini 金鑰", text: $inputKey).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                    Toggle("我已確認此專案未啟用付費帳務", isOn: $confirmed)
                    BusyButton(title: "3. 測試金鑰並連接", busy: store.busy) {
                        let key = inputKey
                        inputKey = ""
                        Task { await store.run { try await store.connect(key, freeConfirmed: confirmed) } }
                    }.disabled(!confirmed || inputKey.isEmpty)
                    if store.connected { Button("移除這台手機的金鑰", role: .destructive) { store.disconnect() } }
                } header: { Text("AI 連接・免費優先") } footer: { Text("金鑰存在 iPhone 鑰匙圈中，不會存入草稿、原始碼或聊天。測試會使用少量可用額度。") }

                Section {
                    Text("照片成片、手動文案、裁切與字幕在手機處理，不需AI額度。可上傳自己的配音，再將MP4儲存到相簿或分享。")
                    Text("AI 文案、配音與字幕辨識直接使用你的 Gemini 帳戶。傳送給 Google 的內容依其服務與免費層條款處理。")
                    Text("如果你勾選並按下「使用 Gemini 優化提示詞」，該影片描述會傳給 Google；優化後會先顯示在 App 供你檢查，不會自動生成或上傳。")
                    Text("免費文生影片會在你同意並按下生成時，把畫面描述傳給 Hugging Face 社群服務；權杖只用於該服務的帳號驗證。")
                    Link("Google Gemini 條款", destination: URL(string: "https://ai.google.dev/gemini-api/terms")!)
                } header: { Text("資料與隱私") }

                Section {
                    Text("社群企劃室的範例、口吻卡、計畫、草稿與成效快照儲存在手機。只有按下分析口吻時會傳送原始範例給 Google；生成貼文、計畫與回覆只傳送口吻卡與當次素材。")
                    Text("沒有自動發布、帳號登入或自動回覆；所有草稿由你檢查後自行分享。分鏡腳本由 Gemini 產生；你同意並按下逐鏡或批次生成後，只把共同描述及各鏡提示詞傳給 Hugging Face。字幕合併在手機處理。")
                    NavigationLink("社群功能來源與 MIT 授權") { SocialCreditsView() }
                } header: { Text("社群企劃室") }

                Section {
                    Link("開啟映文網頁工作室", destination: URL(string: "https://hanben-creative-studio.grost9999.chatgpt.site")!)
                    NavigationLink("隱私政策") { PrivacyView() }
                    Text("映文 1.0.0・iPhone 安裝版").foregroundStyle(.secondary)
                    Text("此版本沒有訂閱與內購。文案頁提供免費文生影片實驗版，使用 Hugging Face 社群服務，需排隊並受免費額度限制。")
                } header: { Text("關於映文") }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("設定").navigationBarTitleDisplayMode(.inline).studioKeyboardControls()
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("映文隱私政策").font(.title2.bold())
                Text("生效日期：2026年10月30日")
                Text("社群功能補充：原始範例僅在你勾選授權並按下「分析口吻」時送交 Google。其他社群生成使用口吻卡、內容 brief 和當次留言，不重送原始範例。手動成效數據不會送交 AI；清除本機範例不會刪除已由 Google 處理的內容。社群資料隨 App 儲存在手機，未提供雲端同步，刪除 App 可能遺失。")
                Text("映文的草稿、匯入照片、影片與輸出作品儲存在你的手機。App沒有自建使用者帳號、廣告或追蹤分析SDK。刪除App時，這些本機資料可能一併移除，請先將需要的作品分享或另存檔案。")
                Text("Gemini金鑰以iPhone鑰匙圈保存。App只在你點選AI生成、連接測試或辨識時，將必要的文字、錄音／影片及金鑰傳送給Google Gemini。若在文生影片頁勾選並按下提示詞優化，該描述也會傳給Gemini；優化結果會先留在手機供你檢查。照片成片與手動剪輯不會把照片或影片送到我們的伺服器。")
                Text("使用AI辨識時，影片暫存上傳到Google Files；App會在辨識成功或失敗後嘗試刪除暫存檔，若網路中斷則仍受Google的檔案保存政策約束。Google依其條款處理資料，免費層內容可能用於改善產品。")
                Text("免費文生影片由 Hugging Face 的 KingNish/wan2-2-fast 社群 Space 提供。你同意並開始生成後，App會將畫面描述及選填的 Hugging Face 權杖傳給該服務。權杖存於這台手機的鑰匙圈，不會傳給 Google。免費服務可能排隊、停機或額度不足；App不會自動改用付費生成。請勿在描述中輸入私人資料，雲端資料依 Hugging Face 及服務維護者政策處理。")
                Link("Hugging Face 隱私政策", destination: URL(string: "https://huggingface.co/privacy")!)
                Text("你可以在免費文生影片頁移除權杖，並在 Hugging Face 帳號設定撤銷權杖。")
                Text("相簿存取採系統選取器，只讀取你選擇的素材。只有按下「存到相簿」時，才會要求新增影片的權限。你也可以不開啟此權限，改用分享或檔案App保存。")
                Text("你可以在設定移除金鑰，並在Google AI Studio撤銷金鑰。如需支援，可透過映文專案的支援頁回報問題，請勿公開金鑰或私人素材。")
            }.padding()
        }.navigationTitle("隱私政策").navigationBarTitleDisplayMode(.inline).studioKeyboardControls()
    }
}

private enum DraftsSheet: Identifiable {
    case history(StudioDraft)
    case video(VideoPreviewItem)

    var id: String {
        switch self {
        case .history(let draft): return "history-\(draft.id.uuidString)"
        case .video(let item): return "video-\(item.id)"
        }
    }
}

struct DraftsView: View {
    @EnvironmentObject private var store: StudioStore
    @State private var exports: [URL] = []
    @State private var activeSheet: DraftsSheet?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.drafts.isEmpty {
                        ContentUnavailableView("先留下第一個靈感", systemImage: "tray", description: Text("在文案工作台按「存草稿」，即可保留商品、文案與版本歷程。"))
                    }
                    ForEach(store.drafts) { draft in
                        HStack(spacing: 12) {
                            Button { store.restore(draft) } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(draft.brief.product.isEmpty ? "未命名創作" : draft.brief.product).font(.headline).foregroundStyle(.primary)
                                    Text("\(draft.revisionHistory.count) 個版本・更新")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text(draft.lastSavedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                            }.buttonStyle(.plain)
                            Button { activeSheet = .history(draft) } label: {
                                Image(systemName: "clock.arrow.circlepath").font(.title3).padding(8)
                            }.buttonStyle(.borderless).accessibilityLabel("查看版本歷程")
                        }
                        .swipeActions {
                            Button("刪除", role: .destructive) { store.deleteDraft(draft.id) }
                        }
                    }
                } header: { Text("這台手機的草稿") } footer: { Text("點草稿載入最新版本；按歷程圖示可查看及還原舊版本。草稿不包含照片與影片素材。") }

                Section("已輸出的影片・點擊預覽") {
                    if exports.isEmpty { Text("完成的MP4會出現在這裡。點選影片即可播放預覽，再分享或儲存到相簿。").foregroundStyle(.secondary) }
                    ForEach(exports, id: \.self) { url in
                        Button { activeSheet = .video(VideoPreviewItem(url: url)) } label: {
                            Label(url.deletingPathExtension().lastPathComponent, systemImage: "play.rectangle")
                        }.accessibilityHint("開啟影片播放器預覽")
                    }
                }
            }
            .navigationTitle("作品與草稿")
            .navigationBarTitleDisplayMode(.inline)
            .studioKeyboardControls()
            .onAppear(perform: reloadExports)
            .sheet(item: $activeSheet) { sheet in
                Group {
                    switch sheet {
                    case .history(let draft): DraftHistorySheet(draft: draft)
                    case .video(let item): VideoPreviewSheet(item: item)
                    }
                }.environmentObject(store)
            }
        }
    }

    private func reloadExports() {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Exports")
        exports = ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey])) ?? [])
            .filter { $0.pathExtension.lowercased() == "mp4" }
            .sorted {
                let left = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let right = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return left > right
            }
    }
}

private struct DraftHistorySheet: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.dismiss) private var dismiss
    let draft: StudioDraft

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(draft.revisionHistory.sorted { $0.version > $1.version }) { revision in
                        Button {
                            store.restore(draft, revision: revision)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("第 \(revision.version) 版").font(.headline)
                                    Spacer()
                                    Text(revision.savedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                }
                                let sample = revision.snapshot.result?.variants.first?.fullText ?? revision.snapshot.manualText
                                Text(sample.isEmpty ? "此版本尚無文案內容" : String(sample.prefix(120)))
                                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                            }.padding(.vertical, 4)
                        }.buttonStyle(.plain)
                    }
                } footer: { Text("選擇某一版會載入該版內容；儲存修改時會建立新版本，不會覆蓋這些歷史記錄。") }
            }
            .navigationTitle("文案版本歷程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
