import Foundation

extension Array {
    /// Returns the element at `index` if it is within bounds, otherwise nil.
    func safe(at index: Int) -> Element? {
        guard index >= 0 && index < self.count else { return nil }
        return self[index]
    }
}
