import CommanderCore
import Foundation
import Testing
@testable import CommanderController

@MainActor
struct ColumnTests {
    @Test func toggleColumnAddsAndRemoves() async {
        let model = await startedHarness().model
        var published: [AppSettings] = []
        model.onSettingsChange = { published.append($0) }

        model.toggleColumn(.kind)
        #expect(model.settings.appearance.columns.last == ColumnSetting(id: .kind, width: 120))
        model.toggleColumn(.ext)
        #expect(!model.settings.appearance.columns.contains { $0.id == .ext })
        #expect(published.count == 2)
    }

    @Test func setColumnsReordersAndKeepsWidths() async {
        let model = await startedHarness().model
        var published = 0
        model.onSettingsChange = { _ in published += 1 }
        let reordered = [ColumnSetting(id: .modified, width: 150), ColumnSetting(id: .ext, width: 60), ColumnSetting(id: .size, width: 72)]

        model.setColumns(reordered)
        model.setColumns(reordered)

        #expect(model.settings.appearance.columns == reordered)
        #expect(published == 1)
    }

    @Test func titlesAndSortColumns() {
        #expect(ColumnID.allCases.map(\.title) == ["Ext", "Size", "Modified", "Created", "Kind"])
        #expect(ColumnID.kind.sortColumn == .kind)
        #expect(ColumnID.ext.sortColumn == .ext)
    }
}
