import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

struct ChosenPhoto: Identifiable { let id = UUID(); let image: UIImage }
struct PhotoFilmView: View {
    @EnvironmentObject private var store: StudioStore
    @State private var selections: [PhotosPickerItem] = []
    @State private var photos: [ChosenPhoto] = []
    @State private var captions = ""
    @State private var seconds = 15
    @State private var ratio = AspectRatio.portrait
    @State private var fill = false
    @State private var voice = "Kore"
    @State private var voiceURL: URL?
    @State private var voiceScript: String?
    @State private var voiceIsManual = false
    @State private var voiceSeconds = 0.0
    @State private var showAudioImporter = false
    @State private var movieURL: URL?
    @State private var progress = 0.0
    @State private var exporting = false
    @State private var previewPlayer: AVPlayer?
    @State private var audioPlayer: AVAudioPlayer?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    StudioCard("商品照片", icon: "photo.on.rectangle.angled") {
                        PhotosPicker(selection: $selections, maxSelectionCount: 8, matching: .images) { Label("從相簿選擇照片（最多8張）", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(.vertical, 18) }.buttonStyle(.bordered)
                        if !photos.isEmpty {
                            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                                HStack {
                                    Image(uiImage: photo.image).resizable().scaledToFill().frame(width: 68, height: 68).clipShape(RoundedRectangle(cornerRadius: 10))
                                    Text("畫面 \(index + 1)").font(.subheadline)
                                    Spacer()
                                    Button { photos.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }.disabled(index == 0)
                                    Button { photos.swapAt(index, index + 1) } label: { Image(systemName: "arrow.down") }.disabled(index == photos.count - 1)
                                    Button(role: .destructive) { photos.remove(at: index) } label: { Image(systemName: "xmark.circle") }
                                }.buttonStyle(.borderless)
                            }
                        }
                        Text("照片只用於這次創作。製作影片在手機完成，不需AI額度。").font(.footnote).foregroundStyle(.secondary)
                    }
                    StudioCard("字幕與配音", icon: "captions.bubble") {
                        Button("使用文案工作台的腳本") { captions = store.voiceover }
                        StudioField(title: "每行一個字幕畫面", text: $captions, multiline: true)
                        Picker("影片長度", selection: $seconds) { ForEach([15, 30, 45], id: \.self) { Text("\($0)秒") } }
                        Picker("畫面比例", selection: $ratio) { ForEach(AspectRatio.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                        Toggle("滿版裁切（關閉則完整保留照片）", isOn: $fill)
                        Picker("AI 配音聲線", selection: $voice) { Text("親切明亮").tag("Kore"); Text("自然中性").tag("Puck"); Text("沉穩有力").tag("Charon") }
                        BusyButton(title: "生成 AI 配音", busy: store.busy) {
                            Task { await store.run {
                                let text = captions.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !text.isEmpty, text.count <= 1600 else { throw StudioError.message("請輸入1600字內的配音稿。") }
                                let data = try await store.service.speech(text: text, voice: voice)
                                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
                                try data.write(to: url); try await useAudio(url, manual: false); voiceScript = text
                            } }
                        }
                        Button("上傳自己的配音（不需AI額度）", systemImage: "folder") { showAudioImporter = true }.buttonStyle(.bordered)
                        if voiceURL != nil {
                            Text("配音約 \(voiceSeconds, specifier: "%.1f") 秒，影片將保留完整配音。").font(.footnote).foregroundStyle(.secondary)
                            HStack {
                                Button("試聽", systemImage: "play.circle") { audioPlayer?.play() }
                                Button("移除配音", role: .destructive) { audioPlayer?.stop(); voiceURL = nil; voiceSeconds = 0; voiceScript = nil }
                            }
                        }
                        Text("AI 配音使用 Gemini 額度，聲音為 AI 生成。字幕依字數分配時間，可自行分行調整。").font(.footnote).foregroundStyle(.secondary)
                    }
                    StudioCard("製作 MP4 影片", icon: "film") {
                        if exporting { ProgressView(value: progress); Text("正在匯出 \(Int(progress * 100))%・請保持 App 在前景").font(.subheadline) }
                        BusyButton(title: "製作並預覽影片", busy: exporting || store.busy) { makeMovie() }
                        if let movieURL {
                            if let previewPlayer { VideoPlayer(player: previewPlayer).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 12)) }
                            HStack {
                                ShareLink(item: movieURL) { Label("分享／存到檔案", systemImage: "square.and.arrow.up") }
                                Spacer()
                                Button("存到相簿", systemImage: "square.and.arrow.down") { Task { await store.run { try await VideoMaker.saveToPhotos(movieURL); store.message = "影片已儲存到相簿。" } } }
                            }.font(.subheadline).buttonStyle(.bordered)
                        }
                    }
                }.padding().disabled(exporting)
            }.background(Color.studioBackground).navigationTitle("照片成片").navigationBarTitleDisplayMode(.inline)
                .onAppear { if captions.isEmpty { captions = store.voiceover } }
                .onChange(of: selections) { _, items in Task { await loadPhotos(items) } }
                .fileImporter(isPresented: $showAudioImporter, allowedContentTypes: [.audio]) { result in
                    Task { await store.run { let original = try result.get(); let copy = try StudioStore.copyIntoDocuments(original, prefix: "voice"); try await useAudio(copy, manual: true) } }
                }
        }
    }
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        await store.run {
            var loaded: [ChosenPhoto] = []
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw StudioError.message("有照片無法讀取，請重新選擇。") }
                let factor = min(1, 1800 / max(image.size.width, image.size.height))
                let targetSize = CGSize(width: image.size.width * factor, height: image.size.height * factor)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let reduced = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
                loaded.append(ChosenPhoto(image: reduced))
            }
            photos = loaded
        }
    }
    private func useAudio(_ url: URL, manual: Bool) async throws {
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        guard duration.isFinite, duration > 0, duration <= 90 else { throw StudioError.message("請選擇90秒以內的配音。") }
        audioPlayer?.stop(); audioPlayer = try AVAudioPlayer(contentsOf: url)
        voiceURL = url; voiceSeconds = duration; voiceIsManual = manual
    }
    private func makeMovie() {
        guard !photos.isEmpty else { store.message = "請先選擇商品照片。"; return }
        if voiceURL != nil && !voiceIsManual && voiceScript != captions.trimmingCharacters(in: .whitespacesAndNewlines) { store.message = "字幕已修改，請重新生成配音，或移除舊配音。"; return }
        let duration = max(Double(seconds), voiceSeconds)
        let settings = MovieSettings(ratio: ratio, duration: duration, fill: fill, brand: store.brief.brand)
        let images = photos.map(\.image), segments = SubtitleFormat.distributed(captions, duration: duration), audio = voiceURL
        audioPlayer?.stop(); previewPlayer?.pause(); exporting = true; progress = 0
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            defer { exporting = false; UIApplication.shared.isIdleTimerDisabled = false }
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try await VideoMaker.photoMovie(images: images, captions: segments, settings: settings, audio: audio) { value in Task { @MainActor in progress = value } }
                }.value
                movieURL = url; previewPlayer = AVPlayer(url: url)
            } catch { store.message = error.localizedDescription }
        }
    }
}
