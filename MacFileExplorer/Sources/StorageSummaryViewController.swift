//
//  StorageSummaryViewController.swift
//  MacFileExplorer
//
//  Summary panel with pie chart and statistics
//

import Cocoa

class StorageSummaryViewController: NSViewController {
    // MARK: - Properties

    private var pieChartView: PieChartView!
    private var statsStackView: NSStackView!
    private var totalSizeLabel: NSTextField!
    private var fileCountLabel: NSTextField!
    private var folderCountLabel: NSTextField!
    private var selectedItemLabel: NSTextField!
    private var legendStackView: NSStackView!

    private var currentItem: StorageItem?
    private var selectedItem: StorageItem?

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Stats section
        setupStatsSection()

        // Pie chart
        setupPieChart()

        // Legend
        setupLegend()

        // Layout
        let mainStack = NSStackView(views: [statsStackView, pieChartView, legendStackView])
        mainStack.orientation = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .centerX
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func setupStatsSection() {
        statsStackView = NSStackView()
        statsStackView.orientation = .vertical
        statsStackView.spacing = 8
        statsStackView.alignment = .leading

        totalSizeLabel = createStatsLabel(title: "Total Size:", value: "-")
        fileCountLabel = createStatsLabel(title: "Files:", value: "-")
        folderCountLabel = createStatsLabel(title: "Folders:", value: "-")
        selectedItemLabel = createStatsLabel(title: "Selected:", value: "-")

        statsStackView.addArrangedSubview(totalSizeLabel)
        statsStackView.addArrangedSubview(fileCountLabel)
        statsStackView.addArrangedSubview(folderCountLabel)
        statsStackView.addArrangedSubview(selectedItemLabel)
    }

    private func createStatsLabel(title: String, value: String) -> NSTextField {
        let label = NSTextField(labelWithString: "\(title) \(value)")
        label.font = NSFont.systemFont(ofSize: 12)
        return label
    }

    private func setupPieChart() {
        pieChartView = PieChartView()
        pieChartView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pieChartView.widthAnchor.constraint(equalToConstant: 250),
            pieChartView.heightAnchor.constraint(equalToConstant: 250)
        ])
    }

    private func setupLegend() {
        legendStackView = NSStackView()
        legendStackView.orientation = .vertical
        legendStackView.spacing = 4
        legendStackView.alignment = .leading
    }

    // MARK: - Public Methods

    func setRootItem(_ item: StorageItem) {
        currentItem = item
        updateStats()
        updatePieChart()
    }

    func setSelectedItem(_ item: StorageItem?) {
        selectedItem = item
        updateSelectedItemLabel()
    }

    // MARK: - Private Methods

    private func updateStats() {
        guard let item = currentItem else { return }

        totalSizeLabel.stringValue = "Total Size: \(item.formattedSize)"
        fileCountLabel.stringValue = "Files: \(formatNumber(item.fileCount))"
        folderCountLabel.stringValue = "Folders: \(formatNumber(item.folderCount))"
    }

    private func updateSelectedItemLabel() {
        if let selected = selectedItem {
            selectedItemLabel.stringValue = "Selected: \(selected.formattedSize) (\(selected.formattedPercentage))"
            selectedItemLabel.isHidden = false
        } else {
            selectedItemLabel.isHidden = true
        }
    }

    private func updatePieChart() {
        guard let item = currentItem else { return }

        let breakdown = item.categoryBreakdown()
        var segments: [PieChartSegment] = []

        for category in StorageCategory.allCases {
            if let size = breakdown[category], size > 0 {
                let percentage = Double(size) / Double(item.totalSize) * 100.0
                segments.append(PieChartSegment(
                    category: category,
                    size: size,
                    percentage: percentage
                ))
            }
        }

        pieChartView.segments = segments
        updateLegend(segments: segments)
    }

    private func updateLegend(segments: [PieChartSegment]) {
        legendStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for segment in segments.sorted(by: { $0.size > $1.size }) {
            let legendItem = createLegendItem(segment: segment)
            legendStackView.addArrangedSubview(legendItem)
        }
    }

    private func createLegendItem(segment: PieChartSegment) -> NSView {
        let container = NSView()

        let colorBox = NSView()
        colorBox.wantsLayer = true
        colorBox.layer?.backgroundColor = segment.category.color.cgColor
        colorBox.layer?.cornerRadius = 2
        colorBox.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "\(segment.category.rawValue): \(ByteCountFormatter.string(fromByteCount: segment.size, countStyle: .file)) (\(String(format: "%.1f%%", segment.percentage)))")
        label.font = NSFont.systemFont(ofSize: 10)
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(colorBox)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            colorBox.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            colorBox.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            colorBox.widthAnchor.constraint(equalToConstant: 12),
            colorBox.heightAnchor.constraint(equalToConstant: 12),

            label.leadingAnchor.constraint(equalTo: colorBox.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Pie Chart Segment
struct PieChartSegment {
    let category: StorageCategory
    let size: Int64
    let percentage: Double
}

// MARK: - Pie Chart View
class PieChartView: NSView {
    var segments: [PieChartSegment] = [] {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !segments.isEmpty else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 10

        var startAngle: CGFloat = -.pi / 2 // Start at top

        for segment in segments {
            let endAngle = startAngle + CGFloat(segment.percentage / 100.0 * 2 * .pi)

            let path = NSBezierPath()
            path.move(to: center)
            path.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: startAngle * 180 / .pi,
                endAngle: endAngle * 180 / .pi,
                clockwise: false
            )
            path.close()

            segment.category.color.setFill()
            path.fill()

            // Draw border
            NSColor.white.setStroke()
            path.lineWidth = 2
            path.stroke()

            startAngle = endAngle
        }
    }
}
