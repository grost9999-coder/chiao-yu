# 攤商記帳王 PRO：首發訂閱上架

狀態：程式與送審資料準備中，尚未在 App Store Connect 建立商品或提交審查。

## 最終價格

App 免費下載，透過 Apple 自動續訂訂閱使用完整功能：

| 方案 | 商品 ID | 台灣要求售價 | 週期 | 新訂閱者優惠 |
| --- | --- | --- | --- | --- |
| 月繳 | `com.qiaoyu.vendorbookpro.pro.monthly` | NT$99 | 1 個月 | 1 個月免費試用 |
| 年繳 | `com.qiaoyu.vendorbookpro.pro.annual` | NT$1,089 | 1 年 | 1 個月免費試用 |

兩者建立在同一訂閱群組「攤商記帳王 PRO」，同一等級；權益相同。年繳相較 12 次月繳共省 NT$99。試用須先由使用者確認 Apple 訂閱，不是安裝當日自行倒數。每個符合資格的 Apple 帳號在同群組只能享一次首次優惠，換月繳／年繳不會再享一次。

App Store Connect 若無 NT$1,089 的價位，不得擅自改成相近價格；先請擁有者選擇可用價位，再更新本文件。商品畫面以 StoreKit 實際回傳價格、幣別及試用資格為準。

## 帳本與付費權益

- 開啟 App、回到前景、交易更新及前景每分鐘重新查詢 StoreKit。
- 只有 Apple 驗證通過、指定商品的 currentEntitlements 才能使用完整帳本；包含 Apple 的有效試用及帳務寬限期。
- 沒有安裝時間、UserDefaults 布林值或測試後門解鎖。
- 到期或退款後，原 WebKit 資料保留；原生「匯出既有帳本備份」仍可用，逐攤輸出既有 `vendor_v29_backup` v1 格式。
- 備份與既有 App 使用相同的持久 WebKit 儲存區及 HTML 檔案 URL，不移動 HTML、不改帳本儲存鍵。
- 不提供雲端同步；恢復購買只恢復訂閱權益，不恢復別台裝置的本機帳本。

## App Store Connect 必做設定

對 App `6817730804`、Bundle ID `com.qiaoyu.vendorbookpro`：

1. 訂閱：建立上述同群組、同等級兩項自動續訂商品，台灣價格與一個月免費首次優惠。加入繁體中文顯示名稱與描述（見 `subscriptions.json`）。
2. 填入各訂閱審查截圖；真實購買頁載入成功後再擷取，不能以文字稿冒充。
3. App 定價設免費下載，確認銷售地區。
4. 檢查付費 App 協議、銀行與稅務狀態。若有法律協議，須帳號擁有者本人確認條款後處理。
5. 提供可公開存取的隱私權政策網址與 App 支援網址。App 內政策已備妥；公開頁仍需發布並核對實際支援聯絡方式，不能填未發布網址。
6. App 隱私依實際行為填寫：帳本本機儲存；沒有開發者帳號、廣告追蹤或開發者分析 SDK；Apple 購買資料依 Apple 流程處理。不要把個人財務資料當成開發者已蒐集的資料。
7. 選擇新建置版本，完成分級、版權、截圖及審查聯絡資料。第一次訂閱須與包含訂閱的 App 版本一起送審。
8. 確認新訂閱在 sandbox/TestFlight 可載入、可試用後，才送審。上傳 IPA 與公開上架是不同步驟。

## App 介紹草稿

攤商記帳王 PRO，幫你把每天的小生意記清楚。

記錄每日銷售、平台收入、攤租與營運費，分開管理採購及耗用成本，查看毛利與營運分析。支援庫存盤點、加工與資產紀錄、備忘、多攤商獨立帳本及 JSON 備份匯入。

本機儲存，請定期匯出備份；本版本沒有自動雲端同步。

訂閱方案：月繳 NT$99，或年繳 NT$1,089。符合資格的新訂閱者可享 1 個月免費試用。確認訂閱後，試用結束將依選擇的週期自動收費續訂；請於當期結束至少 24 小時前透過 Apple 訂閱管理取消。各地售價、資格及扣款資訊以 App Store 顯示為準。訂閱到期不刪除裝置內帳本，仍可匯出備份。

使用條款：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
隱私權政策：上架前填入已發布並驗證的正式網址。

## App Review notes draft

The app uses StoreKit 2 and SubscriptionStoreView for two equivalent auto-renewable subscriptions in one group: monthly and annual. An eligible new subscriber receives a one-month free introductory offer as configured in App Store Connect. All prices and offer eligibility come from StoreKit. No app account login is required.

Restore Purchases and Manage/Cancel Subscription are visible on the subscription screen. After an entitlement expires or is revoked, financial records remain in the persistent on-device WebKit store. A native backup export screen remains available without an active subscription and exports one vendor at a time in the existing JSON backup format. Restoring a purchase does not synchronize bookkeeping data between devices.

## 測試清單（須在 iOS sandbox/TestFlight 實做）

- 第一次開啟：確認兩方案實際價格及符合資格時的一個月免費優惠。
- 非首次用戶：不顯示不適用的免費試用宣稱。
- 取消購買：不開通、不刪資料；pending／未驗證交易亦不開通。
- 月繳、年繳購買與同群組切換；取消續訂後到到期前仍可使用。
- 恢復購買、退款、撤銷、到期、帳務重試與有效寬限期。
- 有效訂閱離線開啟，保留 StoreKit 已驗證快取權益；不能用本機自行倒數代替 Apple 權益。
- 到期後逐攤匯出：零筆、中文名稱、小數、複數攤商、舊版封存及自訂選項，回到現有匯入功能驗證。
- iPhone 小螢幕、橫向、Dynamic Type、VoiceOver 與可見政策／恢復／管理連結。
- GitHub iOS compile 和 Codemagic IPA 建置通過。此工作環境沒有 Xcode，不能以 JavaScript 測試替代 iOS 編譯與購買驗證。

Apple 參考：
- https://developer.apple.com/app-store/subscriptions/
- https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions
- https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/
