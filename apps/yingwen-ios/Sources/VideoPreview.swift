import SwiftUI
import AVKit

struct VideoPreviewItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

struct VideoPreviewSheet: View {
    let item: VideoPreviewItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    @State private var notice: String?

    init(item: VideoPreviewItem) {
        self.item = item
        _player = State(initialValue: AVPlayer(url: item.url))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                HStack {
                    ShareLink(item: item.url) { Label("分享／另存影片", systemImage: "square.and.arrow.up") }
                    Spacer()
                    Button("存到相簿", systemImage: "square.and.arrow.down") {
                        Task {
                            do {
                                try await VideoMaker.saveToPhotos(item.url)
                                notice = "影片已儲存到相簿。"
                            } catch { notice = error.localizedDescription }
                        }
                    }
                }.buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("影片預覽")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { player.pause(); dismiss() }
                }
            }
            .alert("映文", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("知道了", role: .cancel) { notice = nil }
            } message: { Text(notice ?? "") }
        }
        .onAppear { player.play() }
        .onDisappear { player.pause() }
    }
}
