#!/usr/bin/env swift
import Foundation

let domain = "com.macfileexplorer.app"
let plistPath = "\(NSHomeDirectory())/Library/Preferences/\(domain).plist"
let fm = FileManager.default

guard fm.fileExists(atPath: plistPath) else {
    print("No preferences plist at \(plistPath)")
    exit(0)
}

guard let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else {
    print("Failed to read plist as dictionary")
    exit(0)
}

print("Preferences domain: \(domain)")
print("Plist: \(plistPath)\n")

if let paths = dict["grantedDirectoriesPaths"] as? [String], !paths.isEmpty {
    print("grantedDirectoriesPaths:")
    for p in paths { print(" - \(p)") }
} else {
    print("No `grantedDirectoriesPaths` found or it's empty.")
}

if let raw = dict["grantedDirectoryBookmarks"] {
    var datas: [Data] = []
    if let arr = raw as? [Data] { datas = arr }
    else if let arr = raw as? [String] { datas = arr.compactMap { Data(base64Encoded: $0) } }
    else if let d = raw as? Data { datas = [d] }

    if datas.isEmpty {
        print("No bookmarks found in `grantedDirectoryBookmarks`.")
    } else {
        print("\nResolved grantedDirectoryBookmarks:")
        for (i, data) in datas.enumerated() {
            var stale = false
            do {
                let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
                let exists = FileManager.default.fileExists(atPath: url.path)
                print("[\(i)] path=\(url.path)")
                print("     stale=\(stale) exists=\(exists)")
            } catch {
                print("[\(i)] could not resolve bookmark: \(error)")
            }
        }
    }
} else {
    print("No `grantedDirectoryBookmarks` key found.")
}
