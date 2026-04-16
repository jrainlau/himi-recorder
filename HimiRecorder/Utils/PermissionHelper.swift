import Cocoa
import ScreenCaptureKit

/// Helper for checking and requesting screen capture permission.
struct PermissionHelper {
    
    /// Check if screen capture access has been granted (legacy API).
    static func hasScreenCapturePermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    /// Request screen capture access. Opens System Preferences if needed.
    @discardableResult
    static func requestScreenCapturePermission() -> Bool {
        return CGRequestScreenCaptureAccess()
    }
    
    /// Pre-authorize ScreenCaptureKit by making a test query.
    /// This triggers the system permission dialog if not already authorized.
    /// Call this early (e.g. at app launch) so the user authorizes before recording.
    static func preauthorizeScreenCaptureKit() {
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                print("[PermissionHelper] ScreenCaptureKit authorized successfully")
            } catch {
                print("[PermissionHelper] ScreenCaptureKit authorization failed: \(error)")
            }
        }
    }
    
    /// Show an alert guiding the user to enable screen capture permission.
    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = "Himi Recorder 需要屏幕录制权限才能正常工作。\n请在「系统设置 → 隐私与安全性 → 屏幕录制」中允许本应用。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后再说")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenCapturePreferences()
        }
    }
    
    /// Open System Preferences to the Screen Recording pane.
    static func openScreenCapturePreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
