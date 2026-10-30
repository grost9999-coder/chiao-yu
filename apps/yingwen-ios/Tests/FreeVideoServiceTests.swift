import XCTest
@testable import YingwenStudio

final class FreeVideoServiceTests: XCTestCase {
    private let origin = URL(string: "https://kingnish-wan2-2-fast.hf.space")!
    func testGradioVideoResponseUsesSameService() throws {
        let body = #"[{"video":{"url":"https://kingnish-wan2-2-fast.hf.space/gradio_api/file=/tmp/test.mp4"}},42]"#
        let url = try FreeVideoService.videoURL(body, origin: origin)
        XCTAssertEqual(url.host, origin.host)
        XCTAssertTrue(url.path.hasSuffix("test.mp4"))
    }
    func testGradioFilePathFallbackAndHostRestriction() throws {
        let body = #"[{"video":{"path":"/tmp/a video.mp4"}},42]"#
        let url = try FreeVideoService.videoURL(body, origin: origin)
        XCTAssertEqual(url.path, "/gradio_api/file=/tmp/a video.mp4")
        for body in [#"[{"video":{"url":"https://example.com/video.mp4"}}]"#,
                     #"[{"video":{"url":"http://kingnish-wan2-2-fast.hf.space/test.mp4"}}]"#,
                     #"[{"video":{"url":"https://user:password@kingnish-wan2-2-fast.hf.space/test.mp4"}}]"#,
                     "[null]", "null"] {
            XCTAssertThrowsError(try FreeVideoService.videoURL(body, origin: origin))
        }
    }
    func testQuotaErrorIsHelpfulAndDoesNotEchoServiceSecrets() {
        let error = FreeVideoService.serviceError("GPU quota exceeded; private token hf_do_not_echo")
        XCTAssertTrue(error.localizedDescription.contains("額度"))
        XCTAssertFalse(error.localizedDescription.contains("hf_do_not_echo"))
        XCTAssertTrue(FreeVideoService.serviceError("null").localizedDescription.contains("需要登入"))
    }
}
