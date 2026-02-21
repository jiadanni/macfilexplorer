import Foundation
import Cocoa
@testable import MacFileExplorer

/// Mock implementation of ColorManaging for testing
class MockColorManager: ColorManaging {
    var folderColors: [String: NSColor] = [:]
    var globalColor: NSColor? = nil
    var setColorCalls: [(color: NSColor, name: String)] = []
    var removeColorCalls: [String] = []
    
    func setColor(_ color: NSColor, forFolderName name: String) {
        folderColors[name] = color
        setColorCalls.append((color: color, name: name))
    }
    
    func getColor(forFolderName name: String) -> NSColor? {
        return folderColors[name]
    }
    
    func getGlobalFolderColor() -> NSColor? {
        return globalColor
    }
    
    func setGlobalFolderColor(_ color: NSColor?) {
        globalColor = color
    }
    
    func removeColor(forFolderName name: String) {
        folderColors.removeValue(forKey: name)
        removeColorCalls.append(name)
    }
    
    func clearAllColors() {
        folderColors.removeAll()
        globalColor = nil
    }
    
    func getAllColoredFolderNames() -> [String] {
        return Array(folderColors.keys)
    }
    
    func reset() {
        folderColors.removeAll()
        globalColor = nil
        setColorCalls.removeAll()
        removeColorCalls.removeAll()
    }
}
