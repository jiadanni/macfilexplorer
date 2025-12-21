import Foundation

/// Simple debug logger that is compiled out in release builds.
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
    let message = items.map { "\($0)" }.joined(separator: separator)
    NSLog("%@", message)
#endif
}

/// Safe localized comparison helper.
/// Use this instead of direct localizedStandardCompare calls.
extension String {
    func safeLocalizedCompare(_ other: String) -> ComparisonResult {
        // Wrap in autoreleasepool to prevent memory buildup
        autoreleasepool {
            self.localizedStandardCompare(other)
        }
    }
    
    func safeLocalizedCaseInsensitiveCompare(_ other: String) -> ComparisonResult {
        // Wrap in autoreleasepool to prevent memory buildup
        autoreleasepool {
            self.localizedCaseInsensitiveCompare(other)
        }
    }
}
