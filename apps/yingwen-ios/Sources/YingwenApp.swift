import SwiftUI

@main struct YingwenStudioApp: App {
    @StateObject private var store = StudioStore()
    var body: some Scene { WindowGroup { StudioRoot().environmentObject(store).tint(.studioPurple) } }
}
extension Color {
    static let studioPurple = Color(red: 0.40, green: 0.32, blue: 0.85)
    static let studioBackground = Color(uiColor: .systemGroupedBackground)
}
struct StudioRoot: View {
    @EnvironmentObject private var store: StudioStore
    var body: some View {
        TabView(selection: $store.selectedTab) {
            CopyStudioView().tabItem { Label("文案", systemImage: "sparkles") }.tag(0)
            PhotoFilmView().tabItem { Label("照片成片", systemImage: "photo.on.rectangle") }.tag(1)
            VideoEditorView().tabItem { Label("剪輯", systemImage: "scissors") }.tag(2)
            DraftsView().tabItem { Label("草稿", systemImage: "tray.full") }.tag(3)
            SettingsView().tabItem { Label("設定", systemImage: "gearshape") }.tag(4)
        }
        .alert("映文", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("知道了", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}
struct StudioCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    init(_ title: String, icon: String, @ViewBuilder content: () -> Content) { self.title = title; self.icon = icon; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(Color.studioPurple)
            content
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.background, in: RoundedRectangle(cornerRadius: 20))
    }
}
struct StudioField: View {
    let title: String
    @Binding var text: String
    var multiline = false
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            if multiline { TextEditor(text: $text).frame(minHeight: 110).padding(8).background(Color.studioBackground, in: RoundedRectangle(cornerRadius: 10)).scrollContentBackground(.hidden) }
            else { TextField(title, text: $text).textFieldStyle(.roundedBorder) }
        }
    }
}
struct BusyButton: View {
    let title: String
    var busy: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) { HStack { if busy { ProgressView().tint(.white) }; Text(busy ? "處理中…" : title).fontWeight(.semibold) }.frame(maxWidth: .infinity).padding(.vertical, 8) }
            .buttonStyle(.borderedProminent).disabled(busy)
    }
}
