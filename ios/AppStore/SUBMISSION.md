# 攤商記帳王 PRO 新版送審準備

程式已更新；後端、Apple 後台與實際購買驗收須完成 RELEASE-GATES.md。未宣稱已發布或送審。

台灣月繳目標 NT$100，商品 com.qiaoyu.vendorbookpro.pro.monthly。既有年繳目標 NT$1,089，商品 com.qiaoyu.vendorbookpro.pro.annual。兩者同群組、同等級。各地價格、首次優惠與資格以 StoreKit 回傳為準。符合資格的新訂閱者，於有設定首次優惠的方案享一個月免費試用。

使用 product-page-zh-Hant.json 的文字與審查步驟。先完成 ACCOUNTS_SETUP.md 的 Firebase 與 Apple 登入服務；正式建置缺少 Firebase 設定會中止，不上傳尚未啟用帳號功能的版本。

啟用帳號／雲端後，App 隱私問卷須反映與帳號連結的 Email、使用者 ID、主動備份的財務資訊與使用者文字內容，不再填完全不蒐集。沒有廣告或追蹤用途。連同 Firebase SDK 的隱私資訊一起核對。

支援 iPhone／iPad；相機、多圖辨識須在實機確認。原生預覽錄影在 Actions 產生，需逐段檢查。沒有對應 Duo 模擬器時會明確列為待補，不用其他裝置冒充。

仍需擁有者提供審查電話、有效且已驗證的審查帳號，確認新建置、分類、分級、銷售地區、出口合規、付費協議與訂閱審查資料，再提交。
