import XCTest
import UIKit
import AVFoundation
@testable import YingwenStudio

final class StudioTests: XCTestCase {
    func testSubtitleRoundTripAndTrimOffsets() throws {
        let source = [Caption(start: 1.25, end: 4.5, text: "第一句字幕"), Caption(start: 5, end: 8, text: "第二句字幕")]
        let parsed = try SubtitleFormat.parse(SubtitleFormat.srt(source))
        XCTAssertEqual(parsed, source)
        let clipped = SubtitleFormat.clipped(parsed, start: 3, end: 6)
        XCTAssertEqual(clipped, [Caption(start: 0, end: 1.5, text: "第一句字幕"), Caption(start: 2, end: 3, text: "第二句字幕")])
        XCTAssertThrowsError(try SubtitleFormat.parse("1\n00:00:04,000 --> 00:00:02,000\n錯誤時間"))
        XCTAssertThrowsError(try SubtitleFormat.parse("1\n00:00:61,000 --> 00:01:05,000\n錯誤秒數"))
    }
    func testPhotoCaptionsCoverTheWholeDuration() {
        let captions = SubtitleFormat.distributed("第一句\n第二句文字比較長\n第三句", duration: 15)
        XCTAssertEqual(captions.count, 3)
        XCTAssertEqual(captions.first?.start, 0)
        XCTAssertEqual(captions.last?.end ?? 0, 15, accuracy: 0.001)
        XCTAssertEqual(captions[0].end, captions[1].start)
    }
    func testWavHeaderAndPayload() {
        let pcm = Data([0, 0, 1, 0])
        let wav = GeminiService.wav(pcm)
        XCTAssertEqual(wav.count, 48)
        XCTAssertEqual(String(decoding: wav.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: wav[8..<12], as: UTF8.self), "WAVE")
        XCTAssertEqual(wav.suffix(4), pcm)
    }
    @MainActor func testNativePhotoExportAndCaptionedTrim() async throws {
        let size = CGSize(width: 100, height: 160)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.orange.setFill(); context.fill(CGRect(origin: .zero, size: size))
        }
        let movie = try await VideoMaker.photoMovie(images: [image], captions: [Caption(start: 0, end: 1, text: "測試字幕")], settings: MovieSettings(ratio: .portrait, duration: 1, fill: false, brand: "映文"), audio: nil) { _ in }
        defer { try? FileManager.default.removeItem(at: movie) }
        let source = AVURLAsset(url: movie)
        let duration = try await source.load(.duration).seconds
        XCTAssertEqual(duration, 1, accuracy: 0.08)
        let tracks = try await source.loadTracks(withMediaType: .video)
        let dimensions = try await tracks[0].load(.naturalSize)
        XCTAssertEqual(dimensions.width, 720)
        XCTAssertEqual(dimensions.height, 1280)
        let output = try await VideoMaker.trim(video: movie, start: 0.2, end: 0.8, ratio: .square, fill: false, keepAudio: false, captions: [Caption(start: 0.1, end: 0.9, text: "燒錄字幕")])
        defer { try? FileManager.default.removeItem(at: output) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        let outputDuration = try await AVURLAsset(url: output).load(.duration).seconds
        XCTAssertEqual(outputDuration, 0.6, accuracy: 0.08)
    }
}
