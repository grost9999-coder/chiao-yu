import SwiftUI
import UIKit

struct CopyStudioView: View {
    @EnvironmentObject private var store: StudioStore
    @State private var manualText = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("把好商品，說成好故事").font(.title2.bold())
                        Text("一段商品介紹，延伸出文案、配音與短影音。").foregroundStyle(.secondary)
                        Button { store.selectedTab = 4 } label: { Label(store.connected ? "Gemini 已連接・免費優先" : "先連接 Gemini，或直接手動創作", systemImage: store.connected ? "checkmark.shield" : "key") }.font(.subheadline)
                    }.padding(.vertical, 8)
                    StudioCard("認識你的商品", icon: "square.and.pencil") {
                        Button("帶入豆乳雞範例") { store.example() }.font(.subheadline)
                        StudioField(title: "品牌名稱", text: $store.brief.brand)
                        StudioField(title: "商品或服務名稱", text: $store.brief.product)
                        StudioField(title: "商品特色、活動與購買方式", text: $store.brief.facts, multiline: true)
                        StudioField(title: "想吸引誰？", text: $store.brief.audience)
                        Picker("發布平台", selection: $store.brief.platform) { ForEach(["Facebook 貼文", "Instagram / Reels", "TikTok / Shorts", "LINE 訊息"], id: \.self) { Text($0) } }
                        Picker("文案語氣", selection: $store.brief.tone) { ForEach(["親切自然", "食慾誘惑", "幽默有梗", "專業可信", "溫暖故事"], id: \.self) { Text($0) } }
                        Picker("創作目的", selection: $store.brief.goal) { ForEach(["吸引顧客購買", "介紹品牌特色", "增加留言互動"], id: \.self) { Text($0) } }
                        Picker("腳本長度", selection: $store.brief.duration) { ForEach([15, 30, 45], id: \.self) { Text("\($0) 秒") } }
                        BusyButton(title: "生成3組文案與腳本", busy: store.busy) { Task { await store.run { try await store.generateCopy() } } }
                        Text("只使用你提供的商品事實。生成會使用 Gemini 額度；額度用完就停止。").font(.footnote).foregroundStyle(.secondary)
                    }
                    if let result = store.result {
                        ForEach(result.variants) { variant in
                            StudioCard(variant.angle, icon: "text.quote") {
                                Text(variant.fullText).textSelection(.enabled)
                                HStack {
                                    Button("複製", systemImage: "doc.on.doc") { UIPasteboard.general.string = variant.fullText; store.message = "文案已複製。" }
                                    Spacer()
                                    ShareLink(item: variant.fullText) { Label("分享", systemImage: "square.and.arrow.up") }
                                }.buttonStyle(.bordered)
                            }
                        }
                    }
                    StudioCard("手動文案", icon: "pencil.line") {
                        StudioField(title: "也可以直接寫下你的想法", text: $manualText, multiline: true)
                        ShareLink(item: manualText) { Label("分享這篇文案", systemImage: "square.and.arrow.up") }.disabled(manualText.isEmpty)
                    }
                    StudioCard("配音與短影音腳本", icon: "waveform") {
                        StudioField(title: "配音稿（每行一段字幕）", text: $store.voiceover, multiline: true)
                        if let scenes = store.result?.scenes {
                            ForEach(scenes) { scene in VStack(alignment: .leading, spacing: 4) { Text(scene.caption).font(.subheadline.bold()); Text(scene.visual).font(.subheadline).foregroundStyle(.secondary) } }
                        }
                        Button("帶去照片成片", systemImage: "arrow.right.circle") { store.selectedTab = 1 }.buttonStyle(.borderedProminent)
                        if let prompt = store.result?.videoPrompt {
                            DisclosureGroup("AI 動態影片提示詞") { VStack(alignment: .leading, spacing: 12) { Text(prompt).font(.subheadline).textSelection(.enabled); ShareLink(item: prompt) { Label("分享提示詞", systemImage: "square.and.arrow.up") }; Text("全新動態畫面需另接影片生成服務。現階段可先用照片、字幕與配音製作影片。").font(.footnote).foregroundStyle(.secondary) }.padding(.top, 8) }
                        }
                    }
                }.padding()
            }.background(Color.studioBackground).scrollDismissesKeyboard(.interactively)
                .navigationTitle("映文・創作工作室").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("存草稿", systemImage: "square.and.arrow.down") { store.saveDraft() } } }
        }
    }
}
