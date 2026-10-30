import Foundation
import UIKit
import AVFoundation
import Photos

struct MovieSettings {
    var ratio: AspectRatio = .portrait
    var duration: Double = 15
    var fill = false
    var brand = ""
}
enum VideoMaker {
    static func outputURL(_ name: String = "映文短片") throws -> URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("\(name)-\(UUID().uuidString.prefix(8)).mp4")
    }
    static func photoMovie(images: [UIImage], captions: [Caption], settings: MovieSettings, audio: URL?, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard !images.isEmpty, settings.duration > 0, settings.duration <= 90 else { throw StudioError.message("請選照片，並使用90秒內的影片長度。") }
        let size = CGSize(width: settings.ratio.width, height: settings.ratio.height)
        let url = try outputURL()
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size.width, AVVideoHeightKey: size.height, AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_000_000]])
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: settings.ratio.width, kCVPixelBufferHeightKey as String: settings.ratio.height, kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw StudioError.message("無法啟動影片編碼。") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? StudioError.message("無法開始製作影片。") }
        writer.startSession(atSourceTime: .zero)
        let frames = Int((settings.duration * 30).rounded(.up))
        do {
            for index in 0..<frames {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing else { throw writer.error ?? StudioError.message("影片輸出中斷。") }
                    try await Task.sleep(nanoseconds: 2_000_000)
                }
                let t = Double(index) / 30
                let photoIndex = min(images.count - 1, Int(t / settings.duration * Double(images.count)))
                let caption = captions.first { t >= $0.start && t < $0.end }?.text ?? ""
                let buffer = try autoreleasepool { try pixelBuffer(image: images[photoIndex], caption: caption, settings: settings, size: size, attributes: attributes) }
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 30)) else { throw writer.error ?? StudioError.message("畫面編碼失敗。") }
                if index % 15 == 0 { progress(Double(index) / Double(frames)) }
            }
            input.markAsFinished()
            writer.endSession(atSourceTime: CMTime(seconds: settings.duration, preferredTimescale: 600))
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? StudioError.message("影片沒有完整輸出。") }
            progress(1)
            if let audio {
                let merged = try await addAudio(video: url, audio: audio)
                try? FileManager.default.removeItem(at: url)
                return merged
            }
            return url
        } catch {
            writer.cancelWriting(); try? FileManager.default.removeItem(at: url); throw error
        }
    }
    private static func pixelBuffer(image: UIImage, caption: String, settings: MovieSettings, size: CGSize, attributes: [String: Any]) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attributes as CFDictionary, &buffer) == kCVReturnSuccess, let buffer else { throw StudioError.message("手機記憶體不足以製作畫面，請減少照片後重試。") }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { throw StudioError.message("無法建立影片畫面。") }
        context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(context); defer { UIGraphicsPopContext() }
        UIColor(red: 0.14, green: 0.12, blue: 0.19, alpha: 1).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let scale = settings.fill ? max(size.width / image.size.width, size.height / image.size.height) : min(size.width / image.size.width, size.height / image.size.height)
        let width = image.size.width * scale, height = image.size.height * scale
        image.draw(in: CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height))
        let shadow = NSShadow(); shadow.shadowColor = UIColor.black.withAlphaComponent(0.8); shadow.shadowBlurRadius = 5
        if !settings.brand.isEmpty {
            (settings.brand as NSString).draw(in: CGRect(x: size.width * 0.06, y: size.height * 0.055, width: size.width * 0.88, height: 70), withAttributes: [.font: UIFont.systemFont(ofSize: size.width * 0.033, weight: .semibold), .foregroundColor: UIColor.white, .shadow: shadow])
        }
        if !caption.isEmpty {
            UIColor.black.withAlphaComponent(0.52).setFill()
            UIRectFill(CGRect(x: 0, y: size.height * 0.72, width: size.width, height: size.height * 0.28))
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byCharWrapping
            (caption as NSString).draw(in: CGRect(x: size.width * 0.07, y: size.height * 0.775, width: size.width * 0.86, height: size.height * 0.20), withAttributes: [.font: UIFont.systemFont(ofSize: size.width * 0.048, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: paragraph, .shadow: shadow])
        }
        return buffer
    }
    private static func addAudio(video: URL, audio: URL) async throws -> URL {
        let asset = AVURLAsset(url: video), audioAsset = AVURLAsset(url: audio)
        let composition = AVMutableComposition()
        let duration = try await asset.load(.duration)
        guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first, let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw StudioError.message("無法讀取製作好的影片。") }
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceVideo, at: .zero)
        guard let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first, let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw StudioError.message("配音檔案沒有可用的音訊。") }
        let audioDuration = try await audioAsset.load(.duration)
        try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(duration, audioDuration)), of: sourceAudio, at: .zero)
        return try await export(composition: composition, videoComposition: nil)
    }
    static func trim(video: URL, start: Double, end: Double, ratio: AspectRatio, fill: Bool, keepAudio: Bool, captions: [Caption]) async throws -> URL {
        let asset = AVURLAsset(url: video)
        let originalDuration = try await asset.load(.duration).seconds
        guard start >= 0, end > start, end <= originalDuration + 0.05, end - start <= 90 else { throw StudioError.message("裁切區間無效，且單次輸出最多90秒。") }
        guard let source = try await asset.loadTracks(withMediaType: .video).first else { throw StudioError.message("影片沒有可用的畫面。") }
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw StudioError.message("無法建立剪輯軌道。") }
        let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: end - start, preferredTimescale: 600))
        try track.insertTimeRange(range, of: source, at: .zero)
        if keepAudio, let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first, let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) { try audio.insertTimeRange(range, of: sourceAudio, at: .zero) }
        let natural = try await source.load(.naturalSize), preferred = try await source.load(.preferredTransform)
        let rect = CGRect(origin: .zero, size: natural).applying(preferred)
        let size = CGSize(width: ratio.width, height: ratio.height)
        let scale = fill ? max(size.width / abs(rect.width), size.height / abs(rect.height)) : min(size.width / abs(rect.width), size.height / abs(rect.height))
        let transform = preferred.concatenating(CGAffineTransform(translationX: -rect.minX, y: -rect.minY)).concatenating(CGAffineTransform(scaleX: scale, y: scale)).concatenating(CGAffineTransform(translationX: (size.width - abs(rect.width) * scale) / 2, y: (size.height - abs(rect.height) * scale) / 2))
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layerInstruction.setTransform(transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction(); instruction.timeRange = CMTimeRange(start: .zero, duration: range.duration); instruction.layerInstructions = [layerInstruction]
        let videoComposition = AVMutableVideoComposition(); videoComposition.instructions = [instruction]; videoComposition.renderSize = size; videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        let clipped = SubtitleFormat.clipped(captions, start: start, end: end)
        if !clipped.isEmpty {
            let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: size)
            let videoLayer = CALayer(); videoLayer.frame = parent.bounds; parent.addSublayer(videoLayer)
            for caption in clipped {
                let layer = CATextLayer(); layer.string = caption.text; layer.fontSize = size.width * 0.048; layer.font = CGFont("Helvetica-Bold" as CFString)
                layer.foregroundColor = UIColor.white.cgColor; layer.backgroundColor = UIColor.black.withAlphaComponent(0.62).cgColor
                layer.alignmentMode = .center; layer.isWrapped = true; layer.contentsScale = 2
                layer.frame = CGRect(x: size.width * 0.06, y: size.height * 0.11, width: size.width * 0.88, height: size.height * 0.16)
                layer.opacity = 0
                let animation = CABasicAnimation(keyPath: "opacity"); animation.fromValue = 1; animation.toValue = 1
                animation.beginTime = AVCoreAnimationBeginTimeAtZero + caption.start; animation.duration = caption.end - caption.start
                animation.isRemovedOnCompletion = true; animation.fillMode = .removed
                layer.add(animation, forKey: "caption"); parent.addSublayer(layer)
            }
            videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
        }
        return try await export(composition: composition, videoComposition: videoComposition)
    }
    private static func export(composition: AVMutableComposition, videoComposition: AVMutableVideoComposition?) async throws -> URL {
        let url = try outputURL("映文剪輯")
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { throw StudioError.message("無法建立匯出工作。") }
        session.outputURL = url; session.outputFileType = .mp4; session.videoComposition = videoComposition; session.shouldOptimizeForNetworkUse = true
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                session.exportAsynchronously {
                    if session.status == .completed { continuation.resume() }
                    else { continuation.resume(throwing: session.error ?? StudioError.message("影片匯出失敗。")) }
                }
            }
        } catch { try? FileManager.default.removeItem(at: url); throw error }
        return url
    }
    @MainActor static func saveToPhotos(_ url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw StudioError.message("尚未允許儲存影片，可在 iPhone 設定開啟相簿權限，或使用分享另存檔案。") }
        try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }
    }
}
