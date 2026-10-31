import Foundation

/// Calls only this community ZeroGPU Space. No paid inference endpoint or fallback.
struct FreeVideoService {
    static let spaceURL = URL(string: "https://huggingface.co/spaces/KingNish/wan2-2-fast")!
    private let base = URL(string: "https://kingnish-wan2-2-fast.hf.space")!
    let token: String

    func generate(prompt: String, seconds: Int, portrait: Bool) async throws -> URL {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 600
        configuration.timeoutIntervalForResource = 660
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = authorized(base.appendingPathComponent("gradio_api/call/generate_video"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let inputs: [Any] = [NSNull(), prompt, portrait ? 512 : 288, portrait ? 288 : 512,
                            "text, subtitles, watermark, blurry, distorted", seconds, 0, 4, 42, true]
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": inputs])
        let (data, response) = try await session.data(for: request)
        try check(response)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventID = object["event_id"] as? String,
              !eventID.isEmpty, eventID.allSatisfy({ $0.isHexDigit }) else {
            throw StudioError.message("免費服務的回應格式已變更，請稍後再試。")
        }
        let pollURL = base.appendingPathComponent("gradio_api/call/generate_video/" + eventID)
        let (stream, pollResponse) = try await session.bytes(for: authorized(pollURL))
        try check(pollResponse)
        var event = ""
        var payload: [String] = []
        for try await line in stream.lines {
            try Task.checkCancellation()
            if line.hasPrefix("event:") { event = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
            if line.hasPrefix("data:") { payload.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)) }
            // Gradio emits each event's payload on one data line; consume immediately.
            if !payload.isEmpty {
                let body = payload.joined(separator: "\n")
                payload.removeAll()
                if event == "error" { throw Self.serviceError(body) }
                if event == "complete" {
                    let remote = try Self.videoURL(body, origin: base)
                    let (temp, downloadResponse) = try await session.download(for: authorized(remote))
                    try check(downloadResponse)
                    guard let http = downloadResponse as? HTTPURLResponse,
                          (http.mimeType?.hasPrefix("video/") == true || http.mimeType == "application/octet-stream") else {
                        throw StudioError.message("免費服務未傳回可播放的影片。")
                    }
                    let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Exports")
                    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                    let destination = root.appendingPathComponent(UUID().uuidString + ".mp4")
                    try FileManager.default.moveItem(at: temp, to: destination)
                    return destination
                }
            }
        }
        throw StudioError.message("免費服務連線已結束，未取得影片。請稍後重試。")
    }
    private func authorized(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if !token.isEmpty, url.host == base.host { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        return request
    }
    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw StudioError.message("免費服務沒有回應。") }
        switch http.statusCode {
        case 200...299: return
        case 401, 403: throw StudioError.message("此免費服務需要 Hugging Face 登入權杖，或目前限制存取。請填入自己的唯讀權杖後再試。")
        case 429: throw StudioError.message("免費額度已用完或排隊人數過多，請稍後再試；不會切換付費。")
        default: throw StudioError.message("免費服務暫時無法使用（HTTP \(http.statusCode)），請稍後重試。")
        }
    }
    static func serviceError(_ body: String) -> StudioError {
        let lower = body.lowercased()
        if lower.contains("quota") || lower.contains("limit") || lower.contains("duration") {
            return .message("免費 GPU 額度不足或本次運算超過限制，請稍後再試；不會切換付費。")
        }
        if lower.contains("login") || lower.contains("sign in") || lower.contains("authentication") {
            return .message("請填入自己的 Hugging Face 唯讀權杖，再使用免費額度。")
        }
        return .message("免費服務未能完成生成，可能正在忙碌或需要登入。請稍後重試，或填入 Hugging Face 唯讀權杖。")
    }
    static func videoURL(_ body: String, origin: URL) throws -> URL {
        guard let data = body.data(using: .utf8),
              let values = try JSONSerialization.jsonObject(with: data) as? [Any],
              let first = values.first as? [String: Any],
              let video = first["video"] as? [String: Any] else {
            throw StudioError.message("免費服務未傳回影片，請稍後重試。")
        }
        let url: URL?
        if let raw = video["url"] as? String { url = URL(string: raw, relativeTo: origin)?.absoluteURL }
        else if let path = video["path"] as? String {
            var components = URLComponents(url: origin, resolvingAgainstBaseURL: false)!
            components.path = "/gradio_api/file=" + path
            url = components.url
        } else { url = nil }
        guard let url, url.scheme == "https", url.host == origin.host, url.user == nil, url.password == nil else {
            throw StudioError.message("服務傳回不支援的影片網址。")
        }
        return url
    }
}
