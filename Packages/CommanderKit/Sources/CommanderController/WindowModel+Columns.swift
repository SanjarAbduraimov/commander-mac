import CommanderCore

extension WindowModel {
    /// The header menu's checkmark items: an added column goes last with its default width.
    public func toggleColumn(_ id: ColumnID) {
        var columns = settings.appearance.columns
        if let index = columns.firstIndex(where: { $0.id == id }) {
            columns.remove(at: index)
        } else {
            columns.append(ColumnSetting(id: id, width: AppearanceSettings.defaultColumnWidths[id]!))
        }
        setColumns(columns)
    }

    /// Order and widths after the user drags or resizes header columns.
    public func setColumns(_ columns: [ColumnSetting]) {
        guard columns != settings.appearance.columns else { return }
        var settings = settings
        settings.appearance.columns = columns
        updateSettings(settings)
    }
}
