import Foundation
@testable import CommanderCore

func fixtureItem(_ name: String, directory: Bool = false, in parent: String = "/tmp") -> FileItem {
    FileItem(
        name: name,
        url: URL(fileURLWithPath: parent).appendingPathComponent(name, isDirectory: directory),
        kind: directory ? .directory : .file,
        size: directory ? nil : 0,
        modified: Date(timeIntervalSince1970: 0),
        isHidden: name.hasPrefix(".")
    )
}

func fixtureItems(_ names: String...) -> [FileItem] {
    names.map { fixtureItem($0) }
}

func url(_ path: String) -> URL {
    URL(fileURLWithPath: path, isDirectory: true)
}

func tab(at path: String = "/tmp", items names: String...) -> TabState {
    var tab = TabState(path: url(path))
    tab.apply(listing: names.map { fixtureItem($0, in: path) })
    return tab
}
