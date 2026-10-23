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

    func testLaunchShowsBothPanes() {
        let app = launch()

        XCTAssertTrue(waitFor(app.textFields["path.left"], value: path("left")))
        XCTAssertTrue(waitFor(app.textFields["path.right"], value: path("right")))
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha.txt"].waitForExistence(timeout: 5))
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

    func testClickActivatesAndDoubleClickOpensFolder() {
        let app = launch(left: "nested")
        let folder = app.tables["table.left"].staticTexts["sub"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(waitFor(app.groups["pane.right"], value: "active"))

        folder.click()
        XCTAssertTrue(waitFor(app.groups["pane.left"], value: "active"))
        folder.doubleClick()

        XCTAssertTrue(waitFor(app.textFields["path.left"], value: path("nested/sub")))
    }

    func testF5CopiesToOtherPane() {
        let app = launch()
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha.txt"].waitForExistence(timeout: 5))

        app.typeKey(.F5, modifierFlags: [])

        XCTAssertTrue(app.tables["table.right"].staticTexts["alpha.txt"].waitForExistence(timeout: 5))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("right/alpha.txt").path))
    }

    func testDragBetweenPanesMovesOnSameVolume() {
        let app = launch()
        let alpha = app.tables["table.left"].staticTexts["alpha.txt"]
        XCTAssertTrue(alpha.waitForExistence(timeout: 5))

        alpha.press(forDuration: 0.3, thenDragTo: app.tables["table.right"])

        XCTAssertTrue(app.tables["table.right"].staticTexts["alpha.txt"].waitForExistence(timeout: 5))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("right/alpha.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("left/alpha.txt").path))
    }

    func testSidebarOpensPlaceAndCommandKShowsConnectSheet() throws {
        let app = launch()
        let applications = app.outlines["sidebar"].staticTexts["Applications"]
        XCTAssertTrue(applications.waitForExistence(timeout: 5))
        XCTAssertTrue(app.outlines["sidebar"].staticTexts["Locations"].exists)

        applications.click()
        XCTAssertTrue(waitFor(app.textFields["path.left"], value: "/Applications"))

        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Server Address"].waitForExistence(timeout: 5))
        let shot = FileManager.default.temporaryDirectory.appendingPathComponent("sidebar.png")
        try app.windows["Commander"].screenshot().pngRepresentation.write(to: shot)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Server Address"].waitForNonExistence(timeout: 5))
    }

    func testCommandCommaOpensSettings() throws {
        let app = launch()
        XCTAssertTrue(app.windows["Commander"].waitForExistence(timeout: 5))

        app.typeKey(",", modifierFlags: .command)

        let settings = app.windows["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        let shot = FileManager.default.temporaryDirectory.appendingPathComponent("settings.png")
        try settings.screenshot().pngRepresentation.write(to: shot)
        settings.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Shortcuts")).firstMatch.click()
        XCTAssertTrue(settings.staticTexts["Duplicates are detected before a shortcut is assigned."].waitForExistence(timeout: 5))
    }

    func testSpaceMarksAndShowsSelectionBar() throws {
        let app = launch()
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha.txt"].waitForExistence(timeout: 5))

        app.typeKey(.space, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["1 marked in left pane"].waitForExistence(timeout: 5))
        let shot = FileManager.default.temporaryDirectory.appendingPathComponent("selection.png")
        try app.windows["Commander"].screenshot().pngRepresentation.write(to: shot)
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
