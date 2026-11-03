import XCTest
@testable import YingwenStudio

final class FreeVideoServiceTests: XCTestCase {
    private let origin = URL(string: "https://kingnish-wan2-2-fast.hf.space")!

    func testTextToVideoPayloadUsesNoImageAndCorrectPortraitParameters() throws {
        let data = try FreeVideoService.requestBody(prompt: "A paper kite flying over a field", seconds: 6, portrait: true)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let inputs = try XCTUnwrap(object["data"] as? [Any])
        XCTAssertEqual(inputs.count, 10)
        XCTAssertTrue(inputs[0] is NSNull, "T2V must not attach an input image")
        XCTAssertEqual(inputs[1] as? String, "A paper kite flying over a field")
        XCTAssertEqual((inputs[2] as? NSNumber)?.intValue, 512, "API order is height, then width")
        XCTAssertEqual((inputs[3] as? NSNumber)?.intValue, 288)
        XCTAssertEqual((inputs[5] as? NSNumber)?.intValue, 6)
    }

    func testTextToVideoLandscapeParametersAndDurationValidation() throws {
        let data = try FreeVideoService.requestBody(prompt: "A river flowing through a forest", seconds: 8, portrait: false)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let inputs = try XCTUnwrap(object["data"] as? [Any])
        XCTAssertEqual((inputs[2] as? NSNumber)?.intValue, 288)
        XCTAssertEqual((inputs[3] as? NSNumber)?.intValue, 512)
        XCTAssertThrowsError(try FreeVideoService.requestBody(prompt: "test", seconds: 9, portrait: true))
        XCTAssertThrowsError(try FreeVideoService.requestBody(prompt: "   ", seconds: 2, portrait: true))
    }

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
