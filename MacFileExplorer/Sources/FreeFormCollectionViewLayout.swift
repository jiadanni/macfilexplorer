import Cocoa

/// Lightweight layout that wraps a flow layout but exposes a simple free-form API used by the browser.
/// This is intentionally minimal: it provides item size, grid spacing and allows storing per-item positions.
class FreeFormCollectionViewLayout: NSCollectionViewLayout {
    var itemSize: NSSize = NSSize(width: 110, height: 130)
    var gridSpacing: CGFloat = 10.0
    var isFreeForm: Bool = true

    private let flowLayout = NSCollectionViewFlowLayout()
    private var positionOverrides: [IndexPath: CGPoint] = [:]

    override init() {
        super.init()
        flowLayout.itemSize = itemSize
        flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        flowLayout.minimumLineSpacing = gridSpacing
        flowLayout.minimumInteritemSpacing = gridSpacing
        flowLayout.scrollDirection = .vertical
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func prepare() {
        super.prepare()
        flowLayout.itemSize = itemSize
        flowLayout.minimumLineSpacing = gridSpacing
        flowLayout.minimumInteritemSpacing = gridSpacing
        flowLayout.prepare()
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        guard let collectionView = collectionView else { return [] }
        // Ask flowLayout for attributes and then apply overrides for free-form positions
        guard let attrs = flowLayout.layoutAttributesForElements(in: rect) else { return [] }
        for attr in attrs {
            if let idx = attr.indexPath, let override = positionOverrides[idx] {
                attr.frame.origin = override
            }
        }
        return attrs
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        if let attrs = flowLayout.layoutAttributesForItem(at: indexPath) {
            if let override = positionOverrides[indexPath] {
                attrs.frame.origin = override
            }
            return attrs
        }
        return nil
    }

    override var collectionViewContentSize: NSSize {
        return flowLayout.collectionViewContentSize
    }

    override func invalidateLayout() {
        super.invalidateLayout()
        flowLayout.invalidateLayout()
    }

    // API used by FileBrowserViewController
    func position(for indexPath: IndexPath) -> CGPoint? {
        return positionOverrides[indexPath]
    }

    func setPositionWithoutInvalidation(_ pos: CGPoint, for indexPath: IndexPath) {
        positionOverrides[indexPath] = pos
    }

    func snapToGrid() {
        // Align all stored positions to nearest grid point
        var newOverrides: [IndexPath: CGPoint] = [:]
        for (indexPath, p) in positionOverrides {
            let snappedX = round(p.x / gridSpacing) * gridSpacing
            let snappedY = round(p.y / gridSpacing) * gridSpacing
            newOverrides[indexPath] = CGPoint(x: snappedX, y: snappedY)
        }
        positionOverrides = newOverrides
        invalidateLayout()
    }
}
