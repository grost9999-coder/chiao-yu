# Apple／Email 帳號與雲端服務啟用

程式已接入 Firebase Authentication、Cloud Firestore 與帳號刪除函式。**沒有設定後端時，不會假裝登入或雲端儲存成功。** 本機訪客帳本仍可使用；正式簽署建置會要求有效 Firebase 設定，避免發布不能使用的帳號功能。

## 擁有者需要完成的一次設定

1. 在自己的 Firebase 專案加入 iOS App `com.qiaoyu.vendorbookpro`，下載 `GoogleService-Info.plist`。這是 App 用戶端設定，不是服務帳號私鑰。請勿把 `.p8`、服務帳號 JSON 或管理員密鑰放入 App。
2. Authentication → Sign-in method 啟用 Email/Password、Apple；設定中文驗證信與重設密碼信、密碼原則至少 8 字元、Email enumeration protection 與授權網域。
3. Apple Developer → Identifiers → 此 Bundle ID 啟用 Sign in with Apple，更新 App Store provisioning profile。依 Firebase Apple provider 指示填寫 Team ID、Key ID、Services ID（若該設定需要）及 Apple 私鑰；私鑰只放後端控制台。Apple 私密轉寄 Email 如需收到驗證信，須登記 Firebase 寄信網域。
4. 啟用 Cloud Firestore，選定資料地區。部署 `backend/firestore.rules` 與 `firestore.indexes.json`，不可用測試模式公開讀寫。
5. 啟用可部署 Cloud Functions 的方案（Firebase 通常要求 Blaze 計費）。函式部署至 asia-east1，包含帳號刪除與管理員刪除後的資料清理。先確認費用與預算警示；本次沒有替你開通付費方案。
6. 於自己的電腦登入 Firebase CLI，在 repo 執行：

```bash
cd backend
npm --prefix functions install
firebase use YOUR_PROJECT_ID
firebase deploy --only firestore,functions
```

7. 在 Firestore 為 `ledgerDeletion` collection group 的 `expiresAt` 啟用 TTL（七天 tombstone 用來阻擋舊 ID token 寫回資料）。
8. 將 iOS 設定檔 Base64 內容設為 Codemagic 的安全環境變數 `FIREBASE_IOS_CONFIG_BASE64`。或將原檔放到 `ios/VendorLedger/Resources/GoogleService-Info.plist`（此檔已忽略，不建議進 repo）。不要在建置日誌列印內容。
9. 使用同一修正分支重新建置。第一次要在 Apple／Firebase 實際測試登入、驗證信、密碼重設、連結、雲端備份／還原及刪除；不能以程式編譯取代後端啟用。

## 已實作的資料行為

- 可選 Apple 或 Email 註冊／登入。Email 建立後會寄驗證信，驗證前不可讀寫雲端帳本。
- 可於已登入帳號連結另一種登入方式；不同現有帳號不自動合併，以免誤取他人的帳本。
- Firebase 管理登入憑證，憑證不放入 WebView localStorage、JSON 備份或日誌。
- 每個 Firebase UID 對應獨立持久 WKWebsiteDataStore；未登入者使用既有 default store，保留原來資料。登入與登出會重建帳本介面，切換前必須先儲存草稿。
- 登入後自動保存在此裝置。雲端為明確按鈕觸發的「備份／還原」，**不是即時雙向同步**。原有訪客帳本需先匯出 JSON，再由使用者選擇匯入目前帳號的攤商。
- 雲端整份帳本備份上限 25 MB，分段寫入；所有分段完成後才更新可還原版本。SHA-256 驗證傳輸完整性；Firebase UID rules 限制本人、且經驗證帳號存取。
- 發布雲端版本使用 Firestore transaction 檢查目前 revision。其他裝置更新時拒絕覆蓋，要求重新檢查與核對。
- 還原前先驗證格式與完整性、保存本機還原前副本；本機配額不足會嘗試回復舊資料。分享副本是 account snapshot 格式，需以帳號還原工具處理，不冒充單攤 JSON 格式。
- 刪除帳號要求近期重新驗證。Apple 先撤銷 Apple token；後端鎖定寫入、遞迴清理所有雲端版本再刪 Auth 帳號；成功後移除此裝置該帳號儲存空間。訪客與其他 UID 不受影響，已自行匯出的檔案無法代為刪除。
- **刪除帳號不會取消 Apple 訂閱**，App 顯示 Apple 訂閱管理連結。
- 自動保留舊雲端版本，可能增加儲存費用；目前版本不自動清除舊備份，刪除帳號會整體清除。

## 上架驗收不能省略

兩個實際測試帳號、兩台裝置：A 看不到 B；登入與訪客隔離；驗證信與密碼重設可抵達；Apple 隱藏 Email；登入方式連結後同 UID；離線儲存；超過 25 MB；部分分段失敗不切換版本；兩裝置衝突；還原前副本；刪除後 Firebase Auth／Firestore 及裝置資料消失；取消 Apple 訂閱另行處理。

官方依據：
- https://firebase.google.com/docs/ios/setup
- https://firebase.google.com/docs/auth/ios/apple
- https://firebase.google.com/docs/firestore/manage-data/transactions
- https://developer.apple.com/documentation/webkit/wkwebsitedatastore/init(foridentifier:)
