import XCTest

@MainActor
final class SmokeTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        for folder in ["left", "right", "nested/sub", "settings"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        try Data("abc".utf8).write(to: root.appendingPathComponent("left/alpha.txt"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func launch(left: String = "left") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-CKSettingsDirectory", root.appendingPathComponent("settings").path,
            "-CKLeftPath", root.appendingPathComponent(left).path,
            "-CKRightPath", root.appendingPathComponent("right").path,
        ]
        app.launch()
        return app
    }

    func testLaunchShowsMainWindow() {
        let app = launch()

        XCTAssertTrue(app.windows["Commander"].waitForExistence(timeout: 5))
    }
}
