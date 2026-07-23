import Foundation

enum AppSupportPaths {
    private static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "app.claudeflaig.whispy"
    private static let legacyAppSupportDirectoryName = "Blitztext"
    private static let appSupportDirectoryName = "Whispy"

    static var appSupportDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(appSupportDirectoryName, isDirectory: true)
    }

    private static var legacyAppSupportDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(legacyAppSupportDirectoryName, isDirectory: true)
    }

    static var settingsURL: URL {
        appSupportDirectoryURL.appendingPathComponent("settings.json")
    }

    static var localModelsDirectoryURL: URL {
        appSupportDirectoryURL.appendingPathComponent("models", isDirectory: true)
    }

    static var whisperKitModelsDirectoryURL: URL {
        localModelsDirectoryURL.appendingPathComponent("whisperkit", isDirectory: true)
    }

    static var defaultWhisperKitModelURL: URL {
        whisperKitModelsDirectoryURL.appendingPathComponent(
            "openai_whisper-large-v3-v20240930_626MB",
            isDirectory: true
        )
    }

    static var cachesDirectoryURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
    }

    static var preferencesURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).plist")
    }

    static var savedApplicationStateDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Saved Application State", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).savedState", isDirectory: true)
    }

    static func ensureAppSupportDirectoryExists() throws {
        let fileManager = FileManager.default

        // Preserve existing settings, history, and downloaded models from the former
        // Blitztext identity while moving the visible support folder to Whispy.
        if !fileManager.fileExists(atPath: appSupportDirectoryURL.path),
           fileManager.fileExists(atPath: legacyAppSupportDirectoryURL.path) {
            try fileManager.moveItem(at: legacyAppSupportDirectoryURL, to: appSupportDirectoryURL)
        }

        try fileManager.createDirectory(
            at: appSupportDirectoryURL,
            withIntermediateDirectories: true
        )
    }
}
