import XCTest
@testable import YingwenStudio

final class SocialStudioTests: XCTestCase {
    func testUnknownMetricsRemainUnknownAfterRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 100000)
        let item = SocialOutcome(postID: UUID(), platform: "Facebook", title: "測試", publishedAt: date, capturedAt: date,
                                 impressions: 100, likes: 0, comments: nil, shares: 0, saves: 0)
        let restored = try JSONDecoder().decode(SocialOutcome.self, from: JSONEncoder().encode(item))
        XCTAssertNil(restored.comments)
        XCTAssertNil(restored.engagementRate)
        XCTAssertEqual(try SocialOutcome.metric("0"), 0)
        XCTAssertNil(try SocialOutcome.metric("  "))
        for invalid in ["-1", "1.5", "1e6", "1000000001", "9999999999999999999999"] {
            XCTAssertThrowsError(try SocialOutcome.metric(invalid))
        }
    }

    func testComparisonsRequireSamePlatformAndAge() {
        let date = Date(timeIntervalSince1970: 100000)
        let item = SocialOutcome(postID: UUID(), platform: "Facebook", title: "測試", publishedAt: date,
                                 capturedAt: date.addingTimeInterval(24 * 3600), impressions: 100, likes: 2, comments: 1, shares: 1, saves: 0)
        XCTAssertEqual(item.engagementRate!, 0.04, accuracy: 0.0001)
        var other = item
        other.platform = "Instagram"
        XCTAssertFalse(item.comparable(to: other))
        other.platform = item.platform
        other.capturedAt = date.addingTimeInterval(72 * 3600)
        XCTAssertFalse(item.comparable(to: other))
        other.capturedAt = date.addingTimeInterval(48 * 3600)
        XCTAssertTrue(item.comparable(to: other))
    }

    func testDraftSavesPreserveOlderVersions() throws {
        let initial = SocialPost(platform: "Facebook", hook: "開頭", body: "原稿", cta: "留言", hashtags: "", visual: "商品照")
        var workspace = SocialWorkspace()
        workspace.posts = [initial]
        workspace.saveDraft()
        workspace.saveDraft()
        XCTAssertEqual(workspace.drafts.count, 1)
        XCTAssertEqual(workspace.drafts[0].versions.count, 1)
        workspace.posts[0].body = "人工修訂"
        workspace.saveDraft()
        let restored = try JSONDecoder().decode(SocialWorkspace.self, from: JSONEncoder().encode(workspace))
        XCTAssertEqual(restored.drafts[0].versions[0][0].body, "原稿")
        XCTAssertEqual(restored.drafts[0].versions[1][0].body, "人工修訂")
        XCTAssertEqual(restored.activeDraftID, restored.drafts[0].id)
    }

    @MainActor func testLocalPersistenceAndCorruptionDoesNotOverwriteOriginal() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let store = SocialStudioStore(file: file)
        store.data.samples = "我的授權貼文"
        store.data.voice = "短句、自然"
        store.persist()
        let loaded = SocialStudioStore(file: file)
        XCTAssertEqual(loaded.data.samples, store.data.samples)
        XCTAssertEqual(loaded.data.voice, store.data.voice)
        let original = Data("damaged JSON".utf8)
        try original.write(to: file)
        let damaged = SocialStudioStore(file: file)
        XCTAssertNotNil(damaged.error)
        damaged.persist()
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
}
