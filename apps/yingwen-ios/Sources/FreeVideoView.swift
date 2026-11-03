import SwiftUI
import AVKit

struct FreeVideoView: View {
    @EnvironmentObject private var store: StudioStore
    @State private var prompt = ""
    @State private var token = SecureKey.read(account: "huggingface-free") ?? ""
    @State private var seconds = 2
    @State private var portrait = true
    @State private var consent = false
    @State private var promptOptimizationConsent = false
    @State private var task: Task<Void, Never>?
    @State private var busy = false
    @State private var movieURL: URL?
    @State private var player: AVPlayer?
    @State private var previewItem: VideoPreviewItem?
    @State private var status = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                StudioCard("免費純文字生影片・實驗版", icon: "video.badge.waveform") {
                    Text("這是純文字生影片：不需要上傳照片，模型會從文字描述創作新畫面。")
                        .font(.subheadline.weight(.semibold))
                    Text("使用 Hugging Face 社群的 Wan 2.2 Fast。免費 GPU 需排隊，成功率與畫面品質會受當下服務及免費額度影響；不會改用付費影片服務。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("查看服務來源與模型資訊：KingNish / Wan2.2 Fast", destination: FreeVideoService.spaceURL).font(.footnote)
                    StudioField(title: "想生成什麼畫面？可描述主體、動作、場景、鏡頭移動與光線", text: $prompt, multiline: true)
                    Button("帶入豆乳雞影片範例") {
                        prompt = "Close-up of golden crispy Taiwanese fermented tofu fried chicken wings on a paper tray, steam rising gently, warm market lighting, slow cinematic camera push in, appetizing realistic food photography, no text, no logo."
                    }
                    if let generated = store.result?.videoPrompt {
                        Button("帶入文案工作台的影片提示詞") { prompt = generated }
                    }

                    Divider()
                    Toggle("我同意將目前描述傳給 Gemini，選擇性優化成英文影片提示詞", isOn: $promptOptimizationConsent)
                    Button("使用 Gemini 優化描述", systemImage: "sparkles") {
                        let source = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            await store.run {
                                let refined = try await store.service.refineVideoPrompt(source)
                                prompt = refined
                                store.message = "提示詞已更新。請先檢查或編輯，再按免費生成影片。"
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!store.connected || !promptOptimizationConsent || busy || store.busy || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("只有勾選同意並按下優化時，文字才會傳給 Google Gemini。優化結果會先留在此頁供你檢查；你仍可自行修改。未連接 Gemini 時，也可直接以原始描述免費生成。")
                        .font(.footnote).foregroundStyle(.secondary)

                    Picker("影片長度", selection: $seconds) {
                        Text("2 秒・節省額度").tag(2)
                        Text("4 秒").tag(4)
                        Text("6 秒").tag(6)
                        Text("8 秒").tag(8)
                    }
                    Toggle("直式影片（關閉為橫式）", isOn: $portrait)
                    Text("直式 288 × 512，橫式 512 × 288；目前先以低解析度節省免費運算。生成畫面可能與描述或真實商品不同，請檢查成品。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("我同意將這段描述傳給 Hugging Face 社群服務生成影片", isOn: $consent)
                    BusyButton(title: "免費生成純文字影片", busy: busy) { generate() }
                        .disabled(!consent || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.disabled(busy)

                if !status.isEmpty { Text(status).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
                if busy {
                    Button("停止等待", role: .cancel) { task?.cancel() }
                    Text("停止等待不保證能停止雲端已開始的運算，請勿連續重送。").font(.footnote).foregroundStyle(.secondary)
                }
                if let movieURL {
                    StudioCard("生成結果・點擊播放預覽", icon: "play.rectangle") {
                        if let player { VideoPlayer(player: player).frame(height: 300) }
                        Button("全螢幕預覽影片", systemImage: "play.fill") { previewItem = VideoPreviewItem(url: movieURL) }
                            .buttonStyle(.borderedProminent)
                        ShareLink(item: movieURL) { Label("分享／存到檔案", systemImage: "square.and.arrow.up") }
                        Button("存到相簿", systemImage: "square.and.arrow.down") {
                            Task { await store.run { try await VideoMaker.saveToPhotos(movieURL); store.message = "影片已儲存到相簿。" } }
                        }
                    }
                }
                StudioCard("免費帳號連接（選填）", icon: "key") {
                    Text("可先不填。如果服務要求登入或匿名額度不足，再到 Hugging Face 建立免費帳號與唯讀權杖。請勿開啟付費帳務。權杖只存於這台手機的鑰匙圈。")
                        .font(.footnote).foregroundStyle(.secondary)
                    SecureField("貼上 hf_ 開頭的唯讀權杖", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive().textFieldStyle(.roundedBorder)
                    HStack {
                        Button("儲存權杖") { saveToken() }
                        Button("移除", role: .destructive) { SecureKey.remove(account: "huggingface-free"); token = ""; store.message = "已移除 Hugging Face 權杖。" }
                    }
                    Link("建立／管理 Hugging Face 權杖", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                }.disabled(busy)
            }.padding()
        }
        .background(Color.studioBackground)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("文生影片")
        .navigationBarTitleDisplayMode(.inline)
        .studioKeyboardControls()
        .onDisappear { player?.pause() }
        .sheet(item: $previewItem) { VideoPreviewSheet(item: $0) }
    }

    private func saveToken() {
        let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.hasPrefix("hf_"), clean.count > 10,
              clean.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 }) else {
            store.message = "請貼上有效的 hf_ 唯讀權杖."
            return
        }
        do {
            try SecureKey.save(clean, account: "huggingface-free")
            token = clean
            store.message = "免費帳號權杖已安全儲存。"
        } catch { store.message = error.localizedDescription }
    }

    private func generate() {
        guard !busy, consent else { return }
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2000 else { store.message = "請輸入 2000 字內的畫面描述。"; return }
        let key = token.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true
        status = "正在排隊或以純文字生成，可能需要數分鐘…"
        player?.pause()
        player = nil
        movieURL = nil
        let duration = seconds
        let vertical = portrait
        task = Task { @MainActor in
            defer { busy = false; task = nil }
            do {
                let url = try await FreeVideoService(token: key).generateTextToVideo(prompt: text, seconds: duration, portrait: vertical)
                try Task.checkCancellation()
                movieURL = url
                player = AVPlayer(url: url)
                status = "生成完成。影片已保存在 App 內，可點擊預覽、分享或存到相簿。"
            } catch {
                if Task.isCancelled { status = "已停止等待。" }
                else { status = "本次未完成。"; store.message = error.localizedDescription }
            }
        }
    }
}
