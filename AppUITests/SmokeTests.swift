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

    private func waitFor(_ element: XCUIElement, value: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func path(_ relative: String) -> String {
        root.appendingPathComponent(relative).resolvingSymlinksInPath().path
    }

    func testTabSwitchesActivePane() {
        let app = launch()
        let left = app.groups["pane.left"]
        XCTAssertTrue(waitFor(left, value: "active"))

        app.typeKey(.tab, modifierFlags: [])

        XCTAssertTrue(waitFor(app.groups["pane.right"], value: "active"))
        XCTAssertTrue(waitFor(left, value: "inactive"))
    }

    func testBackspaceGoesUp() {
        let app = launch(left: "nested/sub")
        let pathField = app.textFields["path.left"]
        XCTAssertTrue(waitFor(pathField, value: path("nested/sub")))

        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(waitFor(pathField, value: path("nested")))
    }

    func testPathFieldEditingDoesNotTouchFiles() {
        let app = launch()
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha.txt"].waitForExistence(timeout: 5))

        app.typeKey("l", modifierFlags: .command)
        app.typeText("x")
        app.typeKey(.delete, modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("left/alpha.txt").path))
        XCTAssertTrue(app.textFields["path.left"].value(forKey: "hasKeyboardFocus") as? Bool ?? false)
    }
}
