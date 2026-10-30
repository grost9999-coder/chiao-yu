# 攤商記帳 iOS 上架準備專案

狀態：原始碼準備版，尚未經 Xcode 編譯、實機測試或提交 Apple。此 ZIP 不是可安裝 IPA。

內含最新 V29 HTML、iOS WKWebView 主程式、原生 JSON 備份分享、瀏覽器確認與輸入對話框支援、持久化網站資料及 App 圖示。原有帳本內容架構保留。

## 先確認此 App 的識別資料

- 暫定商店名稱：攤商記帳（需確認名稱可用）
- Bundle ID：`com.example.VendorLedger` 是佔位值，必須換成你的唯一識別碼。
- Apple Developer Team：待設定，切勿使用另一個清理 App 的 Bundle ID。
- App Store Connect App ID、支援網址、隱私政策網址：待提供。
- 價格、販售地區、年齡分級、版權人：送審前需決定。

## 不用自備 Mac 的建置途徑

可將此專案放到獨立 GitHub repository，在 Codemagic 的 macOS 建置機生成 Xcode 專案。這裡不包含 Apple 密碼、API 金鑰或簽章憑證。

在 macOS 執行：

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project VendorLedger.xcodeproj -scheme VendorLedger -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

通過模擬器測試後，在 Codemagic 設定 Apple Developer / App Store Connect 整合、正式 Bundle ID 與 App Store 簽章，Archive 並上傳 TestFlight。請使用當時 Apple 接受的最新 Xcode / SDK。此專案未自動提交審查。

## 發佈前測試

1. 真實 iPhone 新增兩個攤商、記帳、切換與更名，確認資料隔離。
2. 強制關閉並重開，確認資料保存。
3. 用「備份／匯入」匯出 JSON，在分享選單選「儲存到檔案」。再選取檔案匯入，核對金額、固定支出與資產。
4. 網頁版資料不會自動轉移到 App；須先匯出再匯入。解除安裝可能刪除本機資料，先備份。
5. 新增單位、刪除紀錄等原有彈窗須實測。
6. 備忘的瀏覽器語音辨識功能不保證在 WKWebView 可用，首次送審前需實測並修正或移除失效入口。
7. 現有本機匯入是逐項合併，並非完整替換還原；要核對是否符合對外產品說明。
8. 核對分析頁成本口徑，尤其原版月支出與每日成本可能重疊。未核對前不可宣稱會計正確性已獲驗證。
9. 原生 JSON 分享必須由實機驗證，目前僅完成程式碼層級檢查。

## 商店素材

Store 目錄提供商店說明與隱私政策草稿。必須補上真實聯絡資訊、將政策發佈為公開 HTTPS 網址、擷取真正 iPhone App 螢幕截圖，再填寫 App Store Connect。不得把未完成的草稿網址提交。

Apple 仍會審核最低功能、穩定性與隱私要求，使用本機 WebView 不代表必定通過。此專案沒有訂閱或付款功能，若要收費請先決定販售方式。
