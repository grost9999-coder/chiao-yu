import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import CoreTransferable

struct ImportedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in SentTransferredFile(movie.url) } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return ImportedMovie(url: copy)
        }
    }
}
struct VideoEditorView: View {
    @EnvironmentObject private var store: StudioStore
    @State private var selection: PhotosPickerItem?
    @State private var sourceURL: URL?
    @State private var sourcePlayer: AVPlayer?
    @State private var outputURL: URL?
    @State private var outputPlayer: AVPlayer?
    @State private var showFileImporter = false
    @State private var duration = 0.0
    @State private var start = 0.0
    @State private var end = 15.0
    @State private var ratio = AspectRatio.portrait
    @State private var fill = false
    @State private var keepAudio = true
    @State private var srt = ""
    @State private var reason = ""
    @State private var playing = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    StudioCard("上傳原始影片", icon: "video") {
                        PhotosPicker(selection: $selection, matching: .videos) { Label("從相簿選擇影片", systemImage: "photo.on.rectangle") }.buttonStyle(.borderedProminent)
                        Button("從檔案選擇影片", systemImage: "folder") { showFileImporter = true }.buttonStyle(.bordered)
                        Text("最長3分鐘；單次輸出最多90秒。AI辨識另限25 MB。").font(.footnote).foregroundStyle(.secondary)
                        if let sourcePlayer {
                            VideoPlayer(player: sourcePlayer).frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("原片長度 \(duration, specifier: "%.1f") 秒").font(.subheadline)
                            HStack {
                                VStack(alignment: .leading) { Text("開始秒數").font(.caption); TextField("開始", value: $start, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder) }
                                VStack(alignment: .leading) { Text("結束秒數").font(.caption); TextField("結束", value: $end, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder) }
                            }
                            Button("預覽選取片段", systemImage: "play.circle") {
                                guard validRange else { store.message = "請設定有效的90秒內區間。"; return }
                                sourcePlayer.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                                sourcePlayer.play(); playing = true
                            }
                            Picker("輸出比例", selection: $ratio) { ForEach(AspectRatio.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                            Toggle("滿版裁切", isOn: $fill)
                            Toggle("保留原音", isOn: $keepAudio)
                        }
                    }
                    StudioCard("字幕與精華", icon: "captions.bubble") {
                        BusyButton(title: "AI 辨識語音字幕", busy: store.busy) {
                            Task { await store.run {
                                guard let sourceURL else { throw StudioError.message("請先選擇影片。") }
                                let transcript = try await store.service.transcribe(url: sourceURL, duration: duration)
                                guard !transcript.segments.isEmpty else { throw StudioError.message("沒有辨識到語音，可以手動輸入字幕。") }
                                srt = SubtitleFormat.srt(transcript.segments)
                            } }
                        }
                        StudioField(title: "SRT字幕（時間以原片為準）", text: $srt, multiline: true)
                        Button("填入字幕格式範例") { srt = "1\n\(SubtitleFormat.stamp(start)) --> \(SubtitleFormat.stamp(min(end, start + 3)))\n寫下第一句字幕" }
                        BusyButton(title: "AI 建議精彩片段", busy: store.busy) {
                            Task { await store.run {
                                guard sourceURL != nil else { throw StudioError.message("請先選擇影片。") }
                                let captions = try SubtitleFormat.parse(srt)
                                guard !captions.isEmpty else { throw StudioError.message("請先辨識或輸入字幕。") }
                                let highlight = try await store.service.highlight(captions: captions, duration: duration)
                                start = min(max(0, highlight.start), max(0, duration - 0.1))
                                end = min(duration, max(start + 0.1, highlight.end), start + 30)
                                reason = highlight.reason
                            } }
                        }
                        if !reason.isEmpty { Text(reason).font(.subheadline).foregroundStyle(.secondary) }
                        Text("AI辨識會將影片傳到 Google，處理後刪除暫存上傳。時間是AI建議，匯出前請校對；手動字幕不需API。").font(.footnote).foregroundStyle(.secondary)
                    }
                    StudioCard("匯出與分享", icon: "square.and.arrow.up") {
                        BusyButton(title: "裁切並燒錄字幕", busy: store.busy) {
                            Task { await store.run {
                                guard let sourceURL, validRange else { throw StudioError.message("請先選影片，並設定有效的90秒內裁切區間。") }
                                sourcePlayer?.pause(); playing = false
                                let captions = try SubtitleFormat.parse(srt)
                                UIApplication.shared.isIdleTimerDisabled = true
                                defer { UIApplication.shared.isIdleTimerDisabled = false }
                                let url = try await VideoMaker.trim(video: sourceURL, start: start, end: end, ratio: ratio, fill: fill, keepAudio: keepAudio, captions: captions)
                                outputURL = url; outputPlayer = AVPlayer(url: url)
                            } }
                        }
                        if let outputURL {
                            if let outputPlayer { VideoPlayer(player: outputPlayer).frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 12)) }
                            HStack {
                                ShareLink(item: outputURL) { Label("分享影片", systemImage: "square.and.arrow.up") }
                                Spacer()
                                Button("存到相簿") { Task { await store.run { try await VideoMaker.saveToPhotos(outputURL); store.message = "已儲存影片到相簿。" } } }
                            }.buttonStyle(.bordered)
                        }
                    }
                }.padding()
            }.background(Color.studioBackground).navigationTitle("影片剪輯").navigationBarTitleDisplayMode(.inline)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: selection) { _, item in
                    Task { await store.run {
                        guard let item, let movie = try await item.loadTransferable(type: ImportedMovie.self) else { throw StudioError.message("無法讀取選取的影片。") }
                        try await load(movie.url)
                    } }
                }
                .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie]) { result in Task { await store.run { try await load(try result.get()) } } }
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        if playing, let sourcePlayer, sourcePlayer.currentTime().seconds >= end { sourcePlayer.pause(); playing = false }
                    }
                }
                .onDisappear { sourcePlayer?.pause(); outputPlayer?.pause(); playing = false }
        }
    }
    private var validRange: Bool { start.isFinite && end.isFinite && start >= 0 && end > start && end <= duration + 0.05 && end - start <= 90 }
    private func load(_ original: URL) async throws {
        let copy = try StudioStore.copyIntoDocuments(original, prefix: "video")
        let length = try await AVURLAsset(url: copy).load(.duration).seconds
        guard length.isFinite, length > 0, length <= 180 else { try? FileManager.default.removeItem(at: copy); throw StudioError.message("請選擇3分鐘以內的影片。") }
        sourcePlayer?.pause(); outputPlayer?.pause(); sourceURL = copy; duration = length
        start = 0; end = min(30, length); sourcePlayer = AVPlayer(url: copy)
        outputURL = nil; outputPlayer = nil; srt = ""; reason = ""
    }
}
