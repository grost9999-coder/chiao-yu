import XCTest
final class UniversalUITests: XCTestCase {
    func testIPadPortraitAndLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-demo","--preview-story","1","-AppleLanguages","(zh-Hant)"]
        app.launch()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout:20))
        XCUIDevice.shared.orientation = .portrait
        sleep(3)
        let portrait = XCTAttachment(screenshot:app.screenshot())
        portrait.name = "iPad-portrait"; portrait.lifetime = .keepAlways; add(portrait)
        XCTAssertGreaterThan(app.frame.height,app.frame.width)
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        XCTAssertGreaterThan(app.frame.width,app.frame.height)
        XCTAssertTrue(app.webViews.firstMatch.exists)
        let landscape = XCTAttachment(screenshot:app.screenshot())
        landscape.name = "iPad-landscape"; landscape.lifetime = .keepAlways; add(landscape)
        XCUIDevice.shared.orientation = .portrait
    }
}
