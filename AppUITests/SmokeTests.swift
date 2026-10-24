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

        XCTAssertTrue(waitFor(app.groups["path.left"], value: path("left")))
        XCTAssertTrue(waitFor(app.groups["path.right"], value: path("right")))
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha"].waitForExistence(timeout: 5))
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
        let pathField = app.groups["path.left"]
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

        XCTAssertTrue(waitFor(app.groups["path.left"], value: path("nested/sub")))
    }

    func testF5CopiesToOtherPane() {
        let app = launch()
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha"].waitForExistence(timeout: 5))

        app.typeKey(.F5, modifierFlags: [])

        XCTAssertTrue(app.tables["table.right"].staticTexts["alpha"].waitForExistence(timeout: 5))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("right/alpha.txt").path))
    }

    func testDragBetweenPanesMovesOnSameVolume() {
        let app = launch()
        let alpha = app.tables["table.left"].staticTexts["alpha"]
        XCTAssertTrue(alpha.waitForExistence(timeout: 5))

        alpha.press(forDuration: 0.3, thenDragTo: app.tables["table.right"])

        XCTAssertTrue(app.tables["table.right"].staticTexts["alpha"].waitForExistence(timeout: 5))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("right/alpha.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("left/alpha.txt").path))
    }

    func testSidebarOpensPlaceAndCommandKShowsConnectSheet() throws {
        let app = launch()
        let applications = app.outlines["sidebar"].staticTexts["Applications"]
        XCTAssertTrue(applications.waitForExistence(timeout: 5))
        XCTAssertTrue(app.outlines["sidebar"].staticTexts["Locations"].exists)

        applications.click()
        XCTAssertTrue(waitFor(app.groups["path.left"], value: "/Applications"))

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
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha"].waitForExistence(timeout: 5))

        app.typeKey(.space, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["1 marked in left pane"].waitForExistence(timeout: 5))
        let shot = FileManager.default.temporaryDirectory.appendingPathComponent("selection.png")
        try app.windows["Commander"].screenshot().pngRepresentation.write(to: shot)
    }

    func testPathFieldEditingDoesNotTouchFiles() {
        let app = launch()
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha"].waitForExistence(timeout: 5))

        app.typeKey("l", modifierFlags: .command)
        app.typeText("x")
        app.typeKey(.delete, modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("left/alpha.txt").path))
        XCTAssertTrue(app.textFields["pathEdit.left"].value(forKey: "hasKeyboardFocus") as? Bool ?? false)
    }

    func testEscapeUnmarks() {
        let app = launch()
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha"].waitForExistence(timeout: 5))

        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["1 marked in left pane"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["1 marked in left pane"].waitForNonExistence(timeout: 5))
    }

    func testCalculateSizeShowsFolderSize() throws {
        try Data("abc".utf8).write(to: root.appendingPathComponent("nested/sub/three.txt"))
        let app = launch(left: "nested")
        XCTAssertTrue(app.tables["table.left"].staticTexts["sub"].waitForExistence(timeout: 5))

        app.typeKey(.return, modifierFlags: [.option, .shift])

        XCTAssertTrue(app.tables["table.left"].staticTexts["3 bytes"].waitForExistence(timeout: 5))
    }

    func testCopyToChosenFolder() {
        let app = launch()
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha"].waitForExistence(timeout: 5))

        app.typeKey(.F5, modifierFlags: .option)
        let field = app.textFields["copyTo.path"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(path("picked") + "/new")
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.buttons["Create & Copy"].firstMatch.waitForExistence(timeout: 5))
        // The alert sits on the sheet, and accessibility also reports an off-screen copy of its buttons.
        let create = app.buttons.matching(identifier: "Create & Copy").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(create)
        create?.click()

        let copied = root.appendingPathComponent("picked/new/alpha.txt").path
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: copied), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: copied))
    }

    func testSinglePaneHidesRightPane() {
        let app = launch()
        let right = app.groups["pane.right"]
        XCTAssertTrue(right.waitForExistence(timeout: 5))

        app.typeKey("\\", modifierFlags: .command)
        XCTAssertTrue(right.waitForNonExistence(timeout: 5))
        app.typeKey("\\", modifierFlags: .command)

        XCTAssertTrue(right.waitForExistence(timeout: 5))
    }

    func testBreadcrumbClickGoesToAncestor() {
        let app = launch(left: "nested/sub")
        let bar = app.groups["path.left"]
        XCTAssertTrue(waitFor(bar, value: path("nested/sub")))

        bar.buttons["nested"].click()

        XCTAssertTrue(waitFor(bar, value: path("nested")))
    }

    func testDragHoverSpringsIntoFolder() throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("right/box"), withIntermediateDirectories: true)
        let app = launch()
        let alpha = app.tables["table.left"].staticTexts["alpha"]
        let box = app.tables["table.right"].staticTexts["box"]
        XCTAssertTrue(alpha.waitForExistence(timeout: 5) && box.waitForExistence(timeout: 5))

        // Window-relative points: an element's coordinate resolves late, and the "box" row is gone once the hover opens it.
        let window = app.windows["Commander"]
        let origin = window.coordinate(withNormalizedOffset: .zero)
        func point(_ element: XCUIElement) -> XCUICoordinate {
            origin.withOffset(CGVector(dx: element.frame.midX - window.frame.minX, dy: element.frame.midY - window.frame.minY))
        }
        point(alpha).press(forDuration: 0.3, thenDragTo: point(box), withVelocity: .default, thenHoldForDuration: 1.5)

        XCTAssertTrue(waitFor(app.groups["path.right"], value: path("right/box")))
        let moved = root.appendingPathComponent("right/box/alpha.txt").path
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: moved), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved))
    }

    func testShortcutsBehindSheetDoNotTouchFiles() {
        let app = launch()
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha"].waitForExistence(timeout: 5))

        app.typeKey(.F5, modifierFlags: .option)
        let field = app.textFields["copyTo.path"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        app.typeKey(.delete, modifierFlags: .command)
        sleep(1)

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("left/alpha.txt").path))
        app.typeKey(.escape, modifierFlags: [])
    }

    func testSinglePaneUsesFullWidth() {
        let app = launch()
        let left = app.groups["pane.left"]
        XCTAssertTrue(app.tables["table.left"].waitForExistence(timeout: 5))
        let half = left.frame.width
        let splitters = app.splitters.count

        app.typeKey("\\", modifierFlags: .command)
        XCTAssertTrue(app.groups["pane.right"].waitForNonExistence(timeout: 5))
        XCTAssertGreaterThan(left.frame.width, half * 1.8)
        // The panes' divider must go too, not stay drawn in the middle of the single pane.
        XCTAssertEqual(app.splitters.count, splitters - 1)

        app.typeKey("\\", modifierFlags: .command)
        XCTAssertTrue(app.groups["pane.right"].waitForExistence(timeout: 5))
        XCTAssertEqual(left.frame.width, half, accuracy: 10)
    }

    func testHeaderMenuTogglesKindColumn() {
        let app = launch()
        let table = app.tables["table.left"]
        XCTAssertTrue(table.staticTexts["alpha"].waitForExistence(timeout: 5))
        XCTAssertTrue(table.buttons["Ext"].exists)
        XCTAssertFalse(table.buttons["Kind"].exists)

        table.buttons["Name"].rightClick()
        app.menuItems["Kind"].click()
        XCTAssertTrue(table.buttons["Kind"].waitForExistence(timeout: 5))

        table.buttons["Name"].rightClick()
        app.menuItems["Kind"].click()
        XCTAssertTrue(table.buttons["Kind"].waitForNonExistence(timeout: 5))
    }

    func testCutShowsScissors() {
        let app = launch()
        let table = app.tables["table.left"]
        XCTAssertTrue(table.staticTexts["alpha"].waitForExistence(timeout: 5))

        app.typeKey("x", modifierFlags: .command)

        XCTAssertTrue(table.images["Cut"].waitForExistence(timeout: 5))
        app.typeKey("c", modifierFlags: .command)
        XCTAssertTrue(table.images["Cut"].waitForNonExistence(timeout: 5))
    }

    func testCopyToBrowserEntersFolder() {
        let app = launch()
        XCTAssertTrue(app.tables["table.left"].staticTexts["alpha"].waitForExistence(timeout: 5))

        app.typeKey(.F5, modifierFlags: .option)
        let field = app.textFields["copyTo.path"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(path("") + "/")
        XCTAssertTrue(app.staticTexts["browser.nested"].waitForExistence(timeout: 5))
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(waitFor(field, value: path("nested") + "/"))
        XCTAssertTrue(app.staticTexts["browser.sub"].waitForExistence(timeout: 5))

        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(waitFor(field, value: path("") + "/"))
        XCTAssertTrue(app.staticTexts["browser.nested"].waitForExistence(timeout: 5))
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(waitFor(field, value: path("nested") + "/"))

        app.typeKey(.return, modifierFlags: .command)

        let copied = root.appendingPathComponent("nested/alpha.txt").path
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: copied), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: copied))
    }
}
