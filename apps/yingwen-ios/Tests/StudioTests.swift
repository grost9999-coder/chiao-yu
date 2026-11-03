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

    func testDraftRevisionStoresManualAndEditedGeneratedCopy() throws {
        var brief = ProductBrief()
        brief.product = "紅麴豆乳雞"
        let variant = CopyVariant(angle: "香氣", title: "初稿標題", body: "初稿內容", cta: "來逛逛", hashtags: ["夜市"])
        let result = CreativeResult(variants: [variant], voiceover: "配音稿", scenes: [StoryScene(visual: "暖色燈光", caption: "香酥上桌")], videoPrompt: "Cinematic close-up")
        var draft = StudioDraft(brief: brief, result: result, voiceover: "配音稿", manualText: "手動初稿")
        let firstDate = Date(timeIntervalSince1970: 100)
        draft.createdAt = firstDate
        draft.updatedAt = firstDate
        draft.revisions = [StudioDraftRevision(version: 1, savedAt: firstDate, snapshot: draft.currentSnapshot)]

        var edited = draft.currentSnapshot
        edited.manualText = "已修改的手動文案"
        if var editedResult = edited.result {
            editedResult.variants[0].body = "已修改的生成文案"
            edited.result = editedResult
        }
        let secondDate = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(draft.recordVersion(edited, at: secondDate), 2)
        XCTAssertNil(draft.recordVersion(edited, at: Date(timeIntervalSince1970: 300)), "相同內容不應建立重複版本")
        XCTAssertEqual(draft.revisionHistory.count, 2)
        XCTAssertEqual(draft.revisionHistory[0].snapshot.manualText, "手動初稿")
        XCTAssertEqual(draft.revisionHistory[1].snapshot.manualText, "已修改的手動文案")
        XCTAssertEqual(draft.revisionHistory[1].snapshot.result?.variants.first?.body, "已修改的生成文案")

        let data = try JSONEncoder().encode(draft)
        let restored = try JSONDecoder().decode(StudioDraft.self, from: data)
        XCTAssertEqual(restored.revisionHistory.count, 2)
        XCTAssertEqual(restored.currentSnapshot.manualText, "已修改的手動文案")
        XCTAssertEqual(restored.currentSnapshot.result?.variants.first?.body, "已修改的生成文案")
    }

    func testLegacyDraftWithoutNewFieldsRemainsReadable() throws {
        let draft = StudioDraft(brief: ProductBrief(), result: nil, voiceover: "舊配音稿")
        let encoded = try JSONEncoder().encode(draft)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "manualText")
        object.removeValue(forKey: "updatedAt")
        object.removeValue(forKey: "revisions")
        let oldFormat = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(StudioDraft.self, from: oldFormat)
        XCTAssertEqual(decoded.voiceover, "舊配音稿")
        XCTAssertEqual(decoded.currentSnapshot.manualText, "")
        XCTAssertNil(decoded.revisions)
        XCTAssertEqual(decoded.revisionHistory.count, 1)
    }

    func testCopyVariantIDStaysStableWhenEdited() {
        var variant = CopyVariant(angle: "切角", title: "初稿", body: "內容", cta: "行動", hashtags: [])
        let originalID = variant.id
        variant.title = "編輯後標題"
        XCTAssertEqual(variant.id, originalID)
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
