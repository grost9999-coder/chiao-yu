import SwiftUI

struct SocialCreditsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("社群功能來源").font(.title2.bold())
                Text("參考 Hao 社群貼文技能書的口吻學習、內容規劃、人工審閱與成效紀錄流程，改寫為映文的原生 iPhone 功能。原始專案使用 MIT 授權。")
                Link("技能介紹", destination: URL(string: "https://freetwai.com/development/skills/social-post")!)
                Link("原始專案 Hao0321/claude-skill-social-post", destination: URL(string: "https://github.com/Hao0321/claude-skill-social-post/tree/c2641ba5ac7d7f722f1cef54b03fbfe553502c7b")!)
                Text("本版本提供手動分享與回覆草稿，不含自動社群管理或自動回覆。沒有承諾貼文觸及或收益。")
                Text(Self.license).font(.caption).textSelection(.enabled)
            }.padding()
        }.navigationTitle("來源與授權").navigationBarTitleDisplayMode(.inline)
    }
    static let license = """
MIT License

Copyright (c) 2026 Hao0321 contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""
}
