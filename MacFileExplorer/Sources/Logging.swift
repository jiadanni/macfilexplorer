import Foundation

/// Simple debug logger that is compiled out in release builds.
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
    let message = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(message, terminator: terminator)
#endif
}
