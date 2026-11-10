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

    /// One workflow's dictation shortcut, for the suite's overview of all shortcuts.
    public struct Shortcut {
        public let title: String
        public let subtitle: String
        public let symbol: String
        /// Mac key glyphs, one per key, e.g. ["fn", "⇧"]. Empty when not set.
        public let keys: [String]
    }

    public static var shortcuts: [Shortcut] {
        guard let appState = delegate?.appState else { return [] }
        return WorkflowType.userVisibleHotkeyCases.map { type in
            let combo = appState.appSettings.hotkeyCombos[type] ?? type.defaultHotkeyCombo
            let keys = combo.isEmpty ? [] : HotkeyBadge.glyphs(for: combo.displayLabel)
                .split(separator: " ").map(String.init)
            return Shortcut(title: appState.displayName(for: type),
                            subtitle: appState.workflowSubtitle(for: type),
                            symbol: type.icon,
                            keys: keys)
        }
    }

    /// How the dictation shortcuts behave: held down, or pressed once.
    public static var hotkeyModeDescription: String {
        guard let appState = delegate?.appState else { return "" }
        return appState.appSettings.hotkeyMode.description
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
