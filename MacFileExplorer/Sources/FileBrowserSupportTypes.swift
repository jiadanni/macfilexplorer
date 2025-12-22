import Cocoa
import Quartz

// MARK: - View Mode

enum ViewMode: String, CaseIterable, Codable {
    case list = "List"
    case icons = "Icons"
    case columns = "Columns"
    case windowsList = "List (Win)"
}

// MARK: - Filter Criteria

enum FileOperationType: String {
    case copy = "copy"
    case move = "move"
    case delete = "delete"
}

struct FilterCriteria: Codable {
    var searchText: String = ""
    var fileTypes: Set<String> = []  // Extensions like "pdf", "jpg", "txt"
    var sizeMin: Int64? = nil         // Minimum size in bytes
    var sizeMax: Int64? = nil         // Maximum size in bytes
    var dateMin: Date? = nil          // Minimum modification date
    var dateMax: Date? = nil          // Maximum modification date
    var includeHidden: Bool = false

    var isActive: Bool {
        !searchText.isEmpty ||
            !fileTypes.isEmpty ||
            sizeMin != nil ||
            sizeMax != nil ||
            dateMin != nil ||
            dateMax != nil ||
            includeHidden
    }

    func matches(_ item: FileItem) -> Bool {
        if !searchText.isEmpty {
            if !item.name.localizedCaseInsensitiveContains(searchText) &&
                !item.url.path.localizedCaseInsensitiveContains(searchText) {
                return false
            }
        }

        if !includeHidden && item.isHidden {
            return false
        }

        if item.isDirectory {
            return true
        }

        if !fileTypes.isEmpty {
            let ext = item.url.pathExtension.lowercased()
            if !fileTypes.contains(ext) && !fileTypes.contains("*") {
                return false
            }
        }

        if let min = sizeMin, item.size < min {
            return false
        }
        if let max = sizeMax, item.size > max {
            return false
        }

        if let min = dateMin, let modDate = item.modificationDate, modDate < min {
            return false
        }
        if let max = dateMax, let modDate = item.modificationDate, modDate > max {
            return false
        }

        return true
    }
}

// MARK: - Root Drop Highlighting

// Root container view that provides a visual highlight when a drag session enters the pane.
protocol RootFileBrowserDropDelegate: AnyObject {
    func rootViewPreferredOperation(for info: NSDraggingInfo) -> NSDragOperation
    func rootViewPerformDrop(urls: [URL], operation: FileOperationType, info: NSDraggingInfo)
}

final class RootFileBrowserView: NSView {
    private var highlightLayer: CALayer?
    weak var dropDelegate: RootFileBrowserDropDelegate?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L10n.text("File browser area"))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(L10n.text("File browser area"))
    }

    private func setHighlighted(_ highlighted: Bool) {
        if highlighted {
            if highlightLayer == nil {
                let layer = CALayer()
                layer.borderColor = NSColor.controlAccentColor.cgColor
                layer.borderWidth = 3
                layer.cornerRadius = 6
                layer.frame = bounds.insetBy(dx: 1, dy: 1)
                layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
                highlightLayer = layer
                self.layer?.addSublayer(layer)
            }
        } else {
            highlightLayer?.removeFromSuperlayer()
            highlightLayer = nil
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let op = dropDelegate?.rootViewPreferredOperation(for: sender) ?? []
        if op != [] {
            setHighlighted(true)
        }
        return op
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setHighlighted(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setHighlighted(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setHighlighted(false)
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setHighlighted(false)
        guard let delegate = dropDelegate else { return false }
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        let op = delegate.rootViewPreferredOperation(for: sender)
        guard op != [] else { return false }
        delegate.rootViewPerformDrop(urls: urls, operation: op == .copy ? .copy : .move, info: sender)
        return true
    }
}

// MARK: - Operation Metrics

struct OperationMetric: Codable {
    let type: String
    let bytes: Int64
    let files: Int
    let duration: TimeInterval
    let timestamp: Date
}

final class OperationMetricsManager {
    private static let key = "operationMetricsLog"
    private static let maxRecords = 200

    static func append(type: String, bytes: Int64, files: Int, start: Date, end: Date) {
        let duration = end.timeIntervalSince(start)
        var existing = load()
        existing.append(OperationMetric(type: type, bytes: bytes, files: files, duration: duration, timestamp: Date()))
        if existing.count > maxRecords { existing.removeFirst(existing.count - maxRecords) }
        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [OperationMetric] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([OperationMetric].self, from: data)
        else { return [] }
        return decoded
    }
}
