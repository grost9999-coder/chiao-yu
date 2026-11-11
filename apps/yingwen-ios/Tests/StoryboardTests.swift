import XCTest
import UIKit
import AVFoundation
@testable import YingwenStudio

final class StoryboardTests: XCTestCase {
    func testPromptAndSettingsChangesRequireNewClipButKeepHistory() throws {
        let url = try VideoMaker.outputURL("分鏡測試")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let script = ShotScript(number: 1, visual: "商品", camera: "推近", caption: "你好", narration: "你好", prompt: "A red box")
        var project = FilmProject(title: "測試", continuity: "Warm light", portrait: true, shots: [FilmShot(script: script, seconds: 2)])
        let clip = ShotClip(filename: url.lastPathComponent, prompt: project.prompt(for: project.shots[0]), seconds: 2, portrait: true)
        project.shots[0].clips = [clip]
        XCTAssertTrue(project.pendingIDs.isEmpty)
        project.shots[0].script.caption = "新字幕"
        XCTAssertTrue(project.pendingIDs.isEmpty, "Caption-only edits need local re-export, not new GPU generation")
        project.shots[0].script.prompt = "A blue box"
        XCTAssertEqual(project.pendingIDs, [project.shots[0].id])
        XCTAssertEqual(project.shots[0].clips.count, 1)
        project.shots[0].script.prompt = script.prompt
        project.portrait = false
        XCTAssertEqual(project.pendingIDs.count, 1)
        let restored = try JSONDecoder().decode(FilmProject.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(restored.shots[0].clips[0].filename, url.lastPathComponent)
        XCTAssertEqual(restored.shots[0].script.caption, "新字幕")
    }

    @MainActor func testOrderedMergeUsesActualDurationsAndExportsCaptions() async throws {
        var files: [URL] = []
        defer { for url in files { try? FileManager.default.removeItem(at: url) } }
        var shots: [FilmShot] = []
        for (index, color) in [UIColor.red, UIColor.blue].enumerated() {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 100)).image { context in
                color.setFill(); context.fill(CGRect(x: 0, y: 0, width: 60, height: 100))
            }
            let movie = try await VideoMaker.photoMovie(images: [image], captions: [], settings: MovieSettings(duration: 1), audio: nil) { _ in }
            files.append(movie)
            let script = ShotScript(number: index + 1, visual: "", camera: "", caption: "第\(index + 1)鏡", narration: "", prompt: "Color \(index)")
            let clip = ShotClip(filename: movie.lastPathComponent, prompt: script.prompt, seconds: 2, portrait: true)
            shots.append(FilmShot(script: script, seconds: 2, clips: [clip]))
        }
        let project = FilmProject(title: "測試", continuity: "", portrait: true, shots: shots)
        let merged = try await VideoMaker.storyboardMovie(project, captions: true)
        files.append(merged)
        let asset = AVURLAsset(url: merged)
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, 2, accuracy: 0.12, "Use actual downloaded duration rather than requested 2+2 seconds")
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let first = try generator.copyCGImage(at: CMTime(seconds: 0.3, preferredTimescale: 600), actualTime: nil)
        let second = try generator.copyCGImage(at: CMTime(seconds: 1.3, preferredTimescale: 600), actualTime: nil)
        XCTAssertEqual(first.width, 720)
        XCTAssertEqual(first.height, 1280)
        func rgb(_ image: CGImage) -> [UInt8] {
            var pixel = [UInt8](repeating: 0, count: 4)
            pixel.withUnsafeMutableBytes { buffer in
                let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            return pixel
        }
        XCTAssertGreaterThan(rgb(first)[0], rgb(first)[2], "First shot must stay red")
        XCTAssertGreaterThan(rgb(second)[2], rgb(second)[0], "Second shot must stay blue")
    }
}
