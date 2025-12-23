import Cocoa
import Foundation

class SettingsViewController: NSSplitViewController, SettingsSidebarDelegate {

    private var currentContentViewController: NSViewController?
    weak var changeDelegate: SettingsChangeDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        splitView.isVertical = true // Vertical divider for sidebar on left, content on right
        splitView.dividerStyle = .thin

        // Sidebar for navigation
        let sidebarVC = SettingsSidebarViewController()
        sidebarVC.delegate = self
        let sidebarItem = NSSplitViewItem(viewController: sidebarVC)
        sidebarItem.minimumThickness = 150
        sidebarItem.maximumThickness = 250
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        // Initial content area (General settings)
        let initialContentVC = GeneralSettingsViewController()
        initialContentVC.changeDelegate = changeDelegate
        let contentItem = NSSplitViewItem(viewController: initialContentVC)
        contentItem.minimumThickness = 400
        addSplitViewItem(contentItem)
        currentContentViewController = initialContentVC
    }

    // MARK: - SettingsSidebarDelegate

    func settingsSidebarDidSelectSection(_ section: SettingsSection) {
        // Get the content split view item (second item)
        guard splitViewItems.count > 1 else { return }

        // Create new content view controller based on section
        let newContentVC: NSViewController
        switch section {
        case .general:
            let vc = GeneralSettingsViewController()
            vc.changeDelegate = changeDelegate
            newContentVC = vc
        case .appearance:
            let vc = AppearanceSettingsViewController()
            vc.changeDelegate = changeDelegate
            newContentVC = vc
        case .tabs:
            newContentVC = TabsSettingsViewController()
        case .toolbar:
            newContentVC = ToolbarSettingsViewController()
        case .storage:
            newContentVC = StorageSettingsViewController()
        case .fileOperations:
            newContentVC = FileOperationsSettingsViewController()
        case .goMenu:
            newContentVC = GoMenuSettingsViewController()
        case .terminal:
            newContentVC = TerminalSettingsViewController()
        case .permissions:
            newContentVC = PermissionsSettingsViewController()
        case .advanced:
            newContentVC = AdvancedSettingsViewController()
        case .sidebar:
            newContentVC = SidebarSettingsViewController()
        case .contextMenu:
            newContentVC = ContextMenuSettingsViewController()
        }

        // Remove the old content item safely
        guard let oldContentItem = splitViewItems.safe(at: 1) else { return }
        removeSplitViewItem(oldContentItem)

        // Add new content item
        let newContentItem = NSSplitViewItem(viewController: newContentVC)
        newContentItem.minimumThickness = 400
        addSplitViewItem(newContentItem)

        currentContentViewController = newContentVC

        // Always start scrolled to the top when switching sections
        scrollContentToTop(from: newContentVC.view)
    }

    private func scrollContentToTop(from root: NSView) {
        if let scrollView = root as? NSScrollView {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            return
        }

        for subview in root.subviews {
            scrollContentToTop(from: subview)
        }
    }
    
    // MARK: - Settings Application
    
    func applyChanges() {
        PendingSettings.shared.applyChanges()
    }
    
    func cancelChanges() {
        PendingSettings.shared.cancelChanges()
        // Reload the current view controller to reset UI
        if let currentVC = currentContentViewController {
            let section: SettingsSection
            switch currentVC {
            case is GeneralSettingsViewController:
                section = .general
            case is AppearanceSettingsViewController:
                section = .appearance
            case is TabsSettingsViewController:
                section = .tabs
            case is ToolbarSettingsViewController:
                section = .toolbar
            case is StorageSettingsViewController:
                section = .storage
            case is FileOperationsSettingsViewController:
                section = .fileOperations
            case is GoMenuSettingsViewController:
                section = .goMenu
            case is TerminalSettingsViewController:
                section = .terminal
            case is PermissionsSettingsViewController:
                section = .permissions
            case is AdvancedSettingsViewController:
                section = .advanced
            case is SidebarSettingsViewController:
                section = .sidebar
            case is ContextMenuSettingsViewController:
                section = .contextMenu
            default:
                return
            }
            settingsSidebarDidSelectSection(section)
        }
    }
}
