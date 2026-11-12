# 攤商記帳王 PRO iOS

免註冊、免登入的本機帳本。Bundle ID：com.qiaoyu.vendorbookpro。iOS 17+；iPhone／iPad。四種介面語言，20 種業別範本與最多 20 個獨立攤商帳本。

帳本沿用 default 持久化 WebKit 儲存。JSON 備份由用戶逐攤匯出、儲存及匯入；不提供 App 帳號、Firebase 或自動雲端同步。Apple 訂閱權益與帳本還原獨立。

## 建置
macOS 安裝 XcodeGen，於 ios 目錄執行 xcodegen generate，再用 VendorLedger scheme 建置。Codemagic 工作流程位於根目錄 codemagic.yaml；需要 Apple 簽章整合，不需要 Firebase 設定。

## 驗收與上架
見 AppStore/RELEASE-GATES.md、AppStore/SUBMISSION.md 及 product-page-zh-Hant.json。程式更新不代表已發布 TestFlight 或送審。
