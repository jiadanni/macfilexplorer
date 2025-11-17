import Cocoa
import Photos
import AVFoundation

enum PermissionType: String, CaseIterable {
    case fullDiskAccess = "Full Disk Access"
    case photos = "Photos"
    case camera = "Camera"
    case microphone = "Microphone"
    case contacts = "Contacts"
    case calendars = "Calendars"
    case reminders = "Reminders"

    var icon: String {
        switch self {
        case .fullDiskAccess:
            return "internaldrive"
        case .photos:
            return "photo"
        case .camera:
            return "camera"
        case .microphone:
            return "mic"
        case .contacts:
            return "person.crop.circle"
        case .calendars:
            return "calendar"
        case .reminders:
            return "list.bullet"
        }
    }

    var description: String {
        switch self {
        case .fullDiskAccess:
            return "Access to all files on your Mac"
        case .photos:
            return "Access to your Photos library"
        case .camera:
            return "Access to your camera"
        case .microphone:
            return "Access to your microphone"
        case .contacts:
            return "Access to your contacts"
        case .calendars:
            return "Access to your calendars"
        case .reminders:
            return "Access to your reminders"
        }
    }
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case notApplicable

    var displayText: String {
        switch self {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Requested"
        case .notApplicable:
            return "N/A"
        }
    }

    var color: NSColor {
        switch self {
        case .granted:
            return NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        case .denied:
            return NSColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)
        case .notDetermined:
            return NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
        case .notApplicable:
            return .secondaryLabelColor
        }
    }
}

class PermissionsManager {
    static let shared = PermissionsManager()

    private init() {}

    func checkPermissionStatus(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .fullDiskAccess:
            return checkFullDiskAccess()
        case .photos:
            return checkPhotosAccess()
        case .camera:
            return checkCameraAccess()
        case .microphone:
            return checkMicrophoneAccess()
        case .contacts:
            return checkContactsAccess()
        case .calendars:
            return checkCalendarsAccess()
        case .reminders:
            return checkRemindersAccess()
        }
    }

    private func checkFullDiskAccess() -> PermissionStatus {
        // Check if we can access a protected directory
        let testPath = NSHomeDirectory() + "/Library/Safari/CloudTabs.db"
        let fileManager = FileManager.default

        if fileManager.isReadableFile(atPath: testPath) {
            return .granted
        } else if fileManager.fileExists(atPath: testPath) {
            // File exists but not readable = denied
            return .denied
        } else {
            // Try another protected location
            let alternativePath = NSHomeDirectory() + "/Library/Mail"
            if fileManager.isReadableFile(atPath: alternativePath) {
                return .granted
            }
            return .notDetermined
        }
    }

    private func checkPhotosAccess() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notApplicable
        }
    }

    private func checkCameraAccess() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notApplicable
        }
    }

    private func checkMicrophoneAccess() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notApplicable
        }
    }

    private func checkContactsAccess() -> PermissionStatus {
        // Contacts framework check
        // This is a basic implementation
        return .notApplicable
    }

    private func checkCalendarsAccess() -> PermissionStatus {
        // EventKit framework check
        // This is a basic implementation
        return .notApplicable
    }

    private func checkRemindersAccess() -> PermissionStatus {
        // EventKit framework check for reminders
        // This is a basic implementation
        return .notApplicable
    }

    func openSystemPreferences(for type: PermissionType) {
        var urlString = "x-apple.systempreferences:com.apple.preference.security?"

        switch type {
        case .fullDiskAccess:
            urlString += "Privacy_AllFiles"
        case .photos:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos"
        case .camera:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .contacts:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts"
        case .calendars:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        case .reminders:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
