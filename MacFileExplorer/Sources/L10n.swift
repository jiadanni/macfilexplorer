import Foundation

enum L10n {
    static func text(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }
}
