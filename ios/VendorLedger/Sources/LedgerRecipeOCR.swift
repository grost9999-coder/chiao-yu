import Foundation
import Vision
import WebKit

// Recipe photos are recognized entirely on device. No network service or API key.
final class LedgerRecipeOCR {
    private var busy = false

    func recognize(_ body: [String: Any], webView: WKWebView) {
        guard let id = body["id"] as? String, id.count <= 100 else { return }
        guard !busy else {
            reply(["id": id, "error": "正在辨識另一張圖片，請稍後再試。"], webView: webView)
            return
        }
        guard let base64 = body["image"] as? String, base64.count < 12_000_000,
              let data = Data(base64Encoded: base64), !data.isEmpty else {
            reply(["id": id, "error": "圖片格式或大小不符，請重新選取圖片。"], webView: webView)
            return
        }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak webView] in
            var payload: [String: Any] = ["id": id]
            do {
                let text = try Self.text(in: data)
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    payload["error"] = "未辨識到文字，請使用清晰、光線充足的圖片，或直接貼上文字。"
                } else {
                    payload["text"] = text
                    payload["needsReview"] = true
                }
            } catch { payload["error"] = "圖片辨識失敗，請換張圖片或直接貼上文字。" }
            let result = payload
            DispatchQueue.main.async { [weak self, weak webView] in
                self?.busy = false
                if let webView { self?.reply(result, webView: webView) }
            }
        }
    }

    static func text(in data: Data) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // Keep ingredient names and decimal quantities verbatim.
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US", "ja-JP"].filter { supported.contains($0) }
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(data: data, options: [:]).perform([request])
        // Vision may split a table row into several observations. Join by row, then x position.
        var rows: [[VNRecognizedTextObservation]] = []
        for observation in (request.results ?? []).sorted(by: { $0.boundingBox.midY > $1.boundingBox.midY }) {
            if let last = rows.last, let first = last.first,
               abs(first.boundingBox.midY - observation.boundingBox.midY) < min(first.boundingBox.height, observation.boundingBox.height) * 0.45 {
                rows[rows.count - 1].append(observation)
            } else { rows.append([observation]) }
        }
        let lines = rows.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        }
        let text = String(lines.joined(separator: "\n").prefix(20_000))
        return text
    }

    private func reply(_ payload: [String: Any], webView: WKWebView) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('ledger-recipe-ocr',{detail:\(json)}));", completionHandler: nil)
    }
}

