#if SUITE
import AppKit
import SwiftUI

/// Entry points for the Pastely suite, which runs Whispy inside its own process.
public enum WhispySuite {
    /// Shown under the main page of the menu bar popover, so the suite's other
    /// tools are reachable from Whispy's icon.
    @MainActor public static var footer: AnyView?

    @MainActor public static func makeAppDelegate() -> NSApplicationDelegate {
        AppDelegate()
    }

    @MainActor public static func closePopover() {
        NotificationCenter.default.post(name: .dismissPopover, object: nil)
    }
}
#endif
