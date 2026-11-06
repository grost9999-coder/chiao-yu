# 提交前的驗收與缺口

以下檔案與功能已準備；未完成的後台操作不能當成已完成。

| 項目 | 已準備 | 還需實際完成 |
|---|---|---|
| iPad | 裝置家族 1、2，四方向，UI 測試與原生錄影流程 | 驗證直橫向、鍵盤、照片、儲存及取消；確認新 IPA |
| 試用 | 月費目標 100；StoreKit 資格顯示；不合資格顯示正常續訂 | 核對 ASC 價格、優惠日期與地區；合資格與不合資格帳號購買驗收 |
| 帳號 | Apple／Email 選擇、驗證信、重設、連結、刪除、獨立儲存與雲端備份 | Firebase iOS 設定、啟用 providers、部署 rules/functions；Apple capability 與 profile；真實雙帳號雙裝置測試 |
| 展示 | DEBUG 隔離資料、原生模擬器三支錄影與尺寸檢查 | 逐段審視影片；Duo 無 runtime 時待補；多圖照片辨識另做實測錄影 |
| 送審 | 產品頁 JSON、政策／支援頁、審查步驟 | 合併發布政策、核對網址、填電話／審查帳號、隱私問卷／分級／分類／地區／出口合規、選新建置 |

## 隱私填寫
選用帳號與雲端後，不可繼續宣稱完全不蒐集資料。依實際 SDK 與服務核對 Email、使用者 ID、財務資訊與其他使用者內容，目的為 App 功能、帳號與備份，與帳號連結。原始配方照片在裝置辨識，不進入目前雲端備份。

## 文案
避免無資格限制的「首月免費」、以及「全部資料不上傳」「登入即同步」「加工自動扣除全部庫存」。本版為訪客本機儲存、帳號獨立本機儲存、主動雲端備份／還原；不是即時雙向同步。

## 影片
GitHub Actions：Native iPhone and iPad preview recordings。
產物：VendorLedger-native-AppPreviews。
每個可用裝置三支 20 秒 MP4，附原生來源、封面、manifest 與 simulator 名單。
recorded_needs_visual_review 表示已錄製與通過尺寸檢查，仍需檢視內容。
pending_device_runtime 表示沒有匹配裝置，沒有產生替代影片。

## 啟用
正式 Codemagic 建置需要 FIREBASE_IOS_CONFIG_BASE64；缺少時會提早中止。Firebase Functions 可能需 Blaze 付費方案，由擁有者確認費用後啟用；本次未代為開通計費。
