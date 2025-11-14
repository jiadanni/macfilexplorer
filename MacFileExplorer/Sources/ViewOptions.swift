import Foundation

enum GroupByOption: String, CaseIterable {
    case none = "None"
    case name = "Name"
    case kind = "Kind"
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case size = "Size"
    case tags = "Tags"
}

enum SortByOption: String, CaseIterable {
    case name = "Name"
    case kind = "Kind"
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case size = "Size"
    case tags = "Tags"
}

enum LabelPosition: String, CaseIterable {
    case bottom = "Bottom"
    case right = "Right"
}

enum BackgroundType: String, CaseIterable {
    case defaultBackground = "Default"
    case color = "Color"
    case picture = "Picture"
}

struct ViewOptions {
    // View mode settings
    var alwaysOpenInIconView: Bool = false
    var browseInIconView: Bool = false

    // Grouping and sorting
    var groupBy: GroupByOption = .none
    var sortBy: SortByOption = .name
    var sortAscending: Bool = true

    // Icon view settings
    var iconSize: Double = 64.0 // 16 to 512
    var gridSpacing: Double = 50.0 // 0 to 100
    var textSize: Int = 12 // 10 to 16
    var labelPosition: LabelPosition = .bottom

    // Display options
    var showItemInfo: Bool = false
    var showIconPreview: Bool = true

    // Background
    var backgroundType: BackgroundType = .defaultBackground
    var backgroundColor: String? = nil // Hex color
    var backgroundPicturePath: String? = nil

    // List view settings
    var showPreviewColumn: Bool = false
    var useRelativeDates: Bool = true
    var calculateAllSizes: Bool = false

    // Columns to show in list view
    var showDateModified: Bool = true
    var showDateCreated: Bool = true
    var showDateAdded: Bool = false
    var showSize: Bool = true
    var showKind: Bool = true
    var showVersion: Bool = false
    var showComments: Bool = false
    var showTags: Bool = false
}

// UserDefaults extension for ViewOptions
extension UserDefaults {
    enum ViewOptionsKeys {
        static let alwaysOpenInIconView = "ViewOptions.alwaysOpenInIconView"
        static let browseInIconView = "ViewOptions.browseInIconView"
        static let groupBy = "ViewOptions.groupBy"
        static let sortBy = "ViewOptions.sortBy"
        static let sortAscending = "ViewOptions.sortAscending"
        static let iconSize = "ViewOptions.iconSize"
        static let gridSpacing = "ViewOptions.gridSpacing"
        static let textSize = "ViewOptions.textSize"
        static let labelPosition = "ViewOptions.labelPosition"
        static let showItemInfo = "ViewOptions.showItemInfo"
        static let showIconPreview = "ViewOptions.showIconPreview"
        static let backgroundType = "ViewOptions.backgroundType"
        static let backgroundColor = "ViewOptions.backgroundColor"
        static let backgroundPicturePath = "ViewOptions.backgroundPicturePath"
        static let showPreviewColumn = "ViewOptions.showPreviewColumn"
        static let useRelativeDates = "ViewOptions.useRelativeDates"
        static let calculateAllSizes = "ViewOptions.calculateAllSizes"
        static let showDateModified = "ViewOptions.showDateModified"
        static let showDateCreated = "ViewOptions.showDateCreated"
        static let showDateAdded = "ViewOptions.showDateAdded"
        static let showSize = "ViewOptions.showSize"
        static let showKind = "ViewOptions.showKind"
        static let showVersion = "ViewOptions.showVersion"
        static let showComments = "ViewOptions.showComments"
        static let showTags = "ViewOptions.showTags"
    }

    func saveViewOptions(_ options: ViewOptions) {
        set(options.alwaysOpenInIconView, forKey: ViewOptionsKeys.alwaysOpenInIconView)
        set(options.browseInIconView, forKey: ViewOptionsKeys.browseInIconView)
        set(options.groupBy.rawValue, forKey: ViewOptionsKeys.groupBy)
        set(options.sortBy.rawValue, forKey: ViewOptionsKeys.sortBy)
        set(options.sortAscending, forKey: ViewOptionsKeys.sortAscending)
        set(options.iconSize, forKey: ViewOptionsKeys.iconSize)
        set(options.gridSpacing, forKey: ViewOptionsKeys.gridSpacing)
        set(options.textSize, forKey: ViewOptionsKeys.textSize)
        set(options.labelPosition.rawValue, forKey: ViewOptionsKeys.labelPosition)
        set(options.showItemInfo, forKey: ViewOptionsKeys.showItemInfo)
        set(options.showIconPreview, forKey: ViewOptionsKeys.showIconPreview)
        set(options.backgroundType.rawValue, forKey: ViewOptionsKeys.backgroundType)
        set(options.backgroundColor, forKey: ViewOptionsKeys.backgroundColor)
        set(options.backgroundPicturePath, forKey: ViewOptionsKeys.backgroundPicturePath)
        set(options.showPreviewColumn, forKey: ViewOptionsKeys.showPreviewColumn)
        set(options.useRelativeDates, forKey: ViewOptionsKeys.useRelativeDates)
        set(options.calculateAllSizes, forKey: ViewOptionsKeys.calculateAllSizes)
        set(options.showDateModified, forKey: ViewOptionsKeys.showDateModified)
        set(options.showDateCreated, forKey: ViewOptionsKeys.showDateCreated)
        set(options.showDateAdded, forKey: ViewOptionsKeys.showDateAdded)
        set(options.showSize, forKey: ViewOptionsKeys.showSize)
        set(options.showKind, forKey: ViewOptionsKeys.showKind)
        set(options.showVersion, forKey: ViewOptionsKeys.showVersion)
        set(options.showComments, forKey: ViewOptionsKeys.showComments)
        set(options.showTags, forKey: ViewOptionsKeys.showTags)
    }

    func loadViewOptions() -> ViewOptions {
        var options = ViewOptions()
        options.alwaysOpenInIconView = bool(forKey: ViewOptionsKeys.alwaysOpenInIconView)
        options.browseInIconView = bool(forKey: ViewOptionsKeys.browseInIconView)

        if let groupByString = string(forKey: ViewOptionsKeys.groupBy),
           let groupBy = GroupByOption(rawValue: groupByString) {
            options.groupBy = groupBy
        }

        if let sortByString = string(forKey: ViewOptionsKeys.sortBy),
           let sortBy = SortByOption(rawValue: sortByString) {
            options.sortBy = sortBy
        }

        options.sortAscending = object(forKey: ViewOptionsKeys.sortAscending) as? Bool ?? true
        options.iconSize = object(forKey: ViewOptionsKeys.iconSize) as? Double ?? 64.0
        options.gridSpacing = object(forKey: ViewOptionsKeys.gridSpacing) as? Double ?? 50.0
        options.textSize = object(forKey: ViewOptionsKeys.textSize) as? Int ?? 12

        if let labelPosString = string(forKey: ViewOptionsKeys.labelPosition),
           let labelPos = LabelPosition(rawValue: labelPosString) {
            options.labelPosition = labelPos
        }

        options.showItemInfo = bool(forKey: ViewOptionsKeys.showItemInfo)
        options.showIconPreview = object(forKey: ViewOptionsKeys.showIconPreview) as? Bool ?? true

        if let bgTypeString = string(forKey: ViewOptionsKeys.backgroundType),
           let bgType = BackgroundType(rawValue: bgTypeString) {
            options.backgroundType = bgType
        }

        options.backgroundColor = string(forKey: ViewOptionsKeys.backgroundColor)
        options.backgroundPicturePath = string(forKey: ViewOptionsKeys.backgroundPicturePath)
        options.showPreviewColumn = bool(forKey: ViewOptionsKeys.showPreviewColumn)
        options.useRelativeDates = object(forKey: ViewOptionsKeys.useRelativeDates) as? Bool ?? true
        options.calculateAllSizes = bool(forKey: ViewOptionsKeys.calculateAllSizes)
        options.showDateModified = object(forKey: ViewOptionsKeys.showDateModified) as? Bool ?? true
        options.showDateCreated = object(forKey: ViewOptionsKeys.showDateCreated) as? Bool ?? true
        options.showDateAdded = bool(forKey: ViewOptionsKeys.showDateAdded)
        options.showSize = object(forKey: ViewOptionsKeys.showSize) as? Bool ?? true
        options.showKind = object(forKey: ViewOptionsKeys.showKind) as? Bool ?? true
        options.showVersion = bool(forKey: ViewOptionsKeys.showVersion)
        options.showComments = bool(forKey: ViewOptionsKeys.showComments)
        options.showTags = bool(forKey: ViewOptionsKeys.showTags)

        return options
    }
}
