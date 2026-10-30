import SwiftUI
import AVKit

struct FreeVideoView: View {
    @EnvironmentObject private var store: StudioStore
    @State private var prompt = ""
    @State private var token = SecureKey.read(account: "huggingface-free") ?? ""
    @State private var seconds = 2
    @State private var portrait = true
    @State private var consent = false
    @State private var task: Task<Void, Never>?
    @State private var busy = false
    @State private var movieURL: URL?
    @State private var player: AVPlayer?
    @State private var status = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                StudioCard("免費文生影片・實驗版", icon: "video.badge.waveform") {
                    Text("輸入畫面描述，使用 Hugging Face 社群的 Wan 2.2 免費 GPU 生成短片。無配音，完成後可儲存及分享。")
                    Text("需排隊，免費額度與服務可用性由 Hugging Face 決定。額度不足就停止，不會呼叫付費 API。請保持 App 在前景。").font(.footnote).foregroundStyle(.secondary)
                    Link("查看服務來源：KingNish / Wan2.2 Fast", destination: FreeVideoService.spaceURL).font(.footnote)
                    StudioField(title: "想生成什麼畫面？（英文描述通常較穩定）", text: $prompt, multiline: true)
                    Button("帶入豆乳雞影片範例") {
                        prompt = "Close-up of golden crispy Taiwanese fermented tofu fried chicken wings on a paper tray, steam rising gently, warm market lighting, slow cinematic camera push in, appetizing realistic food photography, no text, no logo."
                    }
                    if let generated = store.result?.videoPrompt {
                        Button("帶入文案工作台的影片提示詞") { prompt = generated }
                    }
                    Picker("短片長度", selection: $seconds) {
                        Text("2 秒・節省額度").tag(2)
                        Text("4 秒").tag(4)
                    }
                    Toggle("直式影片（關閉為橫式）", isOn: $portrait)
                    Text("直式 288 × 512，橫式 512 × 288；先以低解析度節省免費運算。AI 畫面可能與真實商品不同。").font(.footnote).foregroundStyle(.secondary)
                    Toggle("同意將這段描述傳給 Hugging Face 社群服務生成影片", isOn: $consent)
                    BusyButton(title: "免費生成影片", busy: busy) { generate() }
                        .disabled(!consent || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.disabled(busy)
                if !status.isEmpty { Text(status).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
                if busy {
                    Button("停止等待", role: .cancel) { task?.cancel() }
                    Text("停止等待不保證能停止雲端已開始的運算，請勿連續重送。").font(.footnote).foregroundStyle(.secondary)
                }
                if let movieURL {
                    StudioCard("生成結果", icon: "play.rectangle") {
                        if let player { VideoPlayer(player: player).frame(height: 300) }
                        ShareLink(item: movieURL) { Label("分享／存到檔案", systemImage: "square.and.arrow.up") }
                        Button("存到相簿", systemImage: "square.and.arrow.down") {
                            Task { await store.run { try await VideoMaker.saveToPhotos(movieURL); store.message = "影片已儲存到相簿。" } }
                        }
                    }
                }
                StudioCard("免費帳號連接（選填）", icon: "key") {
                    Text("可先不填。如果服務要求登入或匿名額度不足，再到 Hugging Face 建立免費帳號與唯讀權杖。請勿開啟付費帳務。權杖只存於這台手機的鑰匙圈。").font(.footnote).foregroundStyle(.secondary)
                    SecureField("貼上 hf_ 開頭的唯讀權杖", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                    HStack {
                        Button("儲存權杖") { saveToken() }
                        Button("移除", role: .destructive) { SecureKey.remove(account: "huggingface-free"); token = ""; store.message = "已移除 Hugging Face 權杖。" }
                    }
                    Link("建立／管理 Hugging Face 權杖", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                }.disabled(busy)
            }.padding()
        }.background(Color.studioBackground).scrollDismissesKeyboard(.interactively)
            .navigationTitle("文生影片").navigationBarTitleDisplayMode(.inline)
            .onDisappear { player?.pause() }
    }
    private func saveToken() {
        let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.hasPrefix("hf_"), clean.count > 10,
              clean.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 }) else {
            store.message = "請貼上有效的 hf_ 唯讀權杖。"; return
        }
        do { try SecureKey.save(clean, account: "huggingface-free"); token = clean; store.message = "免費帳號權杖已安全儲存。" }
        catch { store.message = error.localizedDescription }
    }
    private func generate() {
        guard !busy, consent else { return }
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2000 else { store.message = "請輸入 2000 字內的畫面描述。"; return }
        let key = token.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true; status = "正在排隊或生成，可能需要數分鐘…"; player?.pause()
        let duration = seconds, vertical = portrait
        task = Task { @MainActor in
            defer { busy = false; task = nil }
            do {
                let url = try await FreeVideoService(token: key).generate(prompt: text, seconds: duration, portrait: vertical)
                try Task.checkCancellation()
                movieURL = url; player = AVPlayer(url: url); status = "生成完成，影片已保存在 App 內，可預覽、分享或存到相簿。"
            } catch {
                if Task.isCancelled { status = "已停止等待。" }
                else { status = "本次未完成。"; store.message = error.localizedDescription }
            }
        }
    }
}
