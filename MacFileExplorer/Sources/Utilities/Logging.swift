import Foundation

/// Simple debug logger that is compiled out in release builds.
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
    let message = items.map { "\($0)" }.joined(separator: separator)
    print("DEBUG: \(sanitizeLogMessage(message))", terminator: terminator)
#endif
}

func sanitizePath(_ path: String) -> String {
    let home = NSHomeDirectory()
    return path.replacingOccurrences(of: home, with: "~")
}

private func sanitizeLogMessage(_ message: String) -> String {
    sanitizePath(message)
}

/// Measure the execution time of a block of code (for profiling)
func measureTime<T>(_ label: String, block: () -> T) -> T {
    let start = CFAbsoluteTimeGetCurrent()
    let result = block()
    let diff = CFAbsoluteTimeGetCurrent() - start
    debugLog("⏱️ \(label) took \(String(format: "%.4f", diff))s")
    return result
}

/// Safe localized comparison helper.
/// Use this instead of direct localizedStandardCompare calls.
extension String {
    func safeLocalizedCompare(_ other: String) -> ComparisonResult {
        self.localizedStandardCompare(other)
    }
    
    func safeLocalizedCaseInsensitiveCompare(_ other: String) -> ComparisonResult {
        self.localizedCaseInsensitiveCompare(other)
    }
}
