import AppKit
import ApplicationServices

@MainActor
enum AccessibilityPermissionService {
    private static var hasPromptedThisSession = false

    static func currentStatus() -> Bool {
        AXIsProcessTrusted()
    }

    static func isTrusted(promptIfNeeded: Bool) -> Bool {
        // Fast path: never call AXIsProcessTrustedWithOptions(prompt: true) when the
        // permission is already granted. On development/ad-hoc builds this avoids
        // macOS repeatedly surfacing Accessibility prompts even though the app is
        // visibly enabled in System Settings.
        if AXIsProcessTrusted() {
            return true
        }

        let shouldPrompt = promptIfNeeded && !hasPromptedThisSession
        if shouldPrompt {
            hasPromptedThisSession = true
        }

        guard shouldPrompt else {
            return AXIsProcessTrusted()
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestPermissionPrompt() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        hasPromptedThisSession = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
