#if SUITE
import AppKit
import SwiftUI

/// Entry points for MacSuite, which runs Whispy inside its own process.
///
/// Whispy's status item and popover become the suite's: the suite gives them
/// its own icon and its own home page, which shows Whispy next to the other
/// tools. Whispy's onboarding and dictation pages stay as they are.
@MainActor
public enum WhispySuite {
    /// The suite's home page, shown instead of Whispy's main page.
    public static var home: AnyView?

    /// The status item's icon while nothing is being dictated. Recording and
    /// processing still show Whispy's own animated icon.
    /// Read while drawing the icon; set once by the suite before launch.
    nonisolated(unsafe) public static var idleIcon: NSImage?
    public static var idleToolTip: String?

    /// Set by the suite: opens its Settings window on Whispy's panes instead
    /// of Whispy's own window.
    public static var onOpenSettings: (() -> Void)?

    private static var delegate: AppDelegate?

    public static func makeAppDelegate() -> NSApplicationDelegate {
        let delegate = AppDelegate()
        self.delegate = delegate
        return delegate
    }

    public static func closePopover() {
        NotificationCenter.default.post(name: .dismissPopover, object: nil)
    }

    /// Whether dictation cannot work yet: no engine set up, or no right to paste.
    public static var needsSetup: Bool {
        guard let appState = delegate?.appState else { return false }
        return !appState.isConfigured || !appState.accessibilityPermissionGranted
    }

    /// Whispy's part of the home page: hints, workflows and recent dictations,
    /// without Whispy's header.
    public static func panel() -> AnyView {
        guard let appState = delegate?.appState else { return AnyView(EmptyView()) }
        return AnyView(WhispyPanel(appState: appState))
    }

    /// The content of one Settings pane, by `SettingsPane` raw value, without
    /// Whispy's sidebar and header.
    public static func settingsPane(_ id: String) -> AnyView {
        guard let appState = delegate?.appState,
              let pane = SettingsPane(rawValue: id) else { return AnyView(EmptyView()) }
        return AnyView(SettingsPaneContent(appState: appState, pane: pane))
    }
}
#endif
