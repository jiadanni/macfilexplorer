import Cocoa

/// Protocol for folder color management to enable dependency injection and testing.
///
/// Implementations provide:
/// - Per-folder custom colors (stored by folder name)
/// - Global folder color applied to all folders
/// - Color persistence
///
/// **Color Priority:**
/// 1. Per-folder custom color (if set)
/// 2. Global folder color (if set)
/// 3. System default (nil)
protocol ColorManaging: AnyObject {
    /// Sets a custom color for a specific folder name.
    ///
    /// - Parameters:
    ///   - color: The color to apply to folders with this name.
    ///   - name: The folder name (last path component).
    func setColor(_ color: NSColor, forFolderName name: String)
    
    /// Gets the custom color for a specific folder name.
    ///
    /// - Parameter name: The folder name (last path component).
    /// - Returns: The custom color if set, nil otherwise.
    func getColor(forFolderName name: String) -> NSColor?
    
    /// Returns the global folder color applied to all folders.
    ///
    /// - Returns: The global folder color if set, nil otherwise.
    func getGlobalFolderColor() -> NSColor?
    
    /// Sets the global folder color applied to all folders.
    ///
    /// - Parameter color: The color to apply, or nil to clear.
    func setGlobalFolderColor(_ color: NSColor?)
    
    /// Removes the custom color for a specific folder name.
    ///
    /// - Parameter name: The folder name (last path component).
    func removeColor(forFolderName name: String)
    
    /// Clears all custom folder colors and the global folder color.
    func clearAllColors()
    
    /// Returns all folder names that have custom colors.
    ///
    /// - Returns: Array of folder names with custom colors.
    func getAllColoredFolderNames() -> [String]
}

/// Default implementation bridge for the singleton.
/// Allows gradual migration from `ColorManager.shared` to injected protocol.
extension ColorManager: ColorManaging {
    func getGlobalFolderColor() -> NSColor? {
        return ColorManager.getGlobalFolderColor()
    }
    
    func setGlobalFolderColor(_ color: NSColor?) {
        ColorManager.setGlobalFolderColor(color)
    }
}
