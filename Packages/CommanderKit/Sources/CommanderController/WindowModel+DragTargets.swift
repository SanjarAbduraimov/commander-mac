import CommanderCore
import Foundation

public struct Breadcrumb: Equatable, Sendable {
    public let title: String
    public let url: URL

    public init(title: String, url: URL) {
        self.title = title
        self.url = url
    }
}

public enum Breadcrumbs {
    public static func of(_ path: URL) -> [Breadcrumb] {
        var url = URL(fileURLWithPath: "/", isDirectory: true)
        var crumbs = [Breadcrumb(title: "/", url: url)]
        for component in path.standardizedFileURL.pathComponents.dropFirst() {
            url = url.appendingPathComponent(component, isDirectory: true)
            crumbs.append(Breadcrumb(title: component, url: url))
        }
        return crumbs
    }
}

extension WindowModel {
    /// Breadcrumb clicks and spring-loading: the pane becomes active and shows `url`.
    public func openFolder(_ side: PaneSide, _ url: URL) {
        activate(side)
        guard !samePath(url, tab(side).path) else { return }
        navigate(side, to: url)
    }

    public func springLoad(_ side: PaneSide, into name: String) {
        guard let item = tab(side).items.first(where: { $0.name == name }), item.isNavigable else { return }
        openFolder(side, item.url)
    }

    public func springLoadParent(_ side: PaneSide) {
        activate(side)
        mutatePane(side) { $0.activeTab.goUp() }
    }

    public func springLoadTab(_ side: PaneSide, at index: Int) {
        activate(side)
        selectTab(side, at: index)
    }

    public func tabPath(_ side: PaneSide, at index: Int) -> URL? {
        let tabs = state[side].tabs
        return tabs.indices.contains(index) ? tabs[index].path : nil
    }

    public func dropOperation(_ urls: [URL], to destination: URL, forceCopy: Bool) -> DropOperation {
        DropPolicy.operation(sources: urls, destination: destination, forceCopy: forceCopy, sameVolume: environment.sameVolume)
    }

    @discardableResult
    public func drop(_ urls: [URL], to destination: URL, forceCopy: Bool) -> Bool {
        switch dropOperation(urls, to: destination, forceCopy: forceCopy) {
        case .copy: operations.start(.copy(sources: urls, destination: destination))
        case .move: operations.start(.move(sources: urls, destination: destination))
        case .none: return false
        }
        return true
    }
}
