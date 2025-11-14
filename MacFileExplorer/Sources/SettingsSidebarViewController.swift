import Cocoa

class SettingsSidebarViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    weak var delegate: SettingsSidebarDelegate?

    private let sections: [SettingsSection] = SettingsSection.allCases
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!

    override func loadView() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = view

        setupTableView()
        setupConstraints()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        delegate?.settingsSidebarDidSelectSection(sections[0])
    }

    private func setupTableView() {
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 5)
        tableView.style = .sourceList
        tableView.allowsEmptySelection = false
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 30

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SectionColumn"))
        column.width = 200
        tableView.addTableColumn(column)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("SettingsSidebarCellView")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? SettingsSidebarCellView

        if cellView == nil {
            cellView = SettingsSidebarCellView()
            cellView?.identifier = cellIdentifier
        }

        if let textField = cellView?.textField {
            textField.stringValue = sections[row].rawValue
            textField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }

        return cellView
    }

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < sections.count {
            delegate?.settingsSidebarDidSelectSection(sections[selectedRow])
        }
    }
}
