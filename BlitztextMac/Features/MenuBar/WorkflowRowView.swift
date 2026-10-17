import SwiftUI

/// A menu-like row: icon, name, one line of detail and the shortcut keys.
struct WorkflowRowView: View {
    let type: WorkflowType
    let enabled: Bool
    var customName: String? = nil
    var subtitle: String? = nil
    var hotkeyLabel: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isHovered && enabled ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(customName ?? type.displayName)
                        .font(.raycast(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle ?? type.subtitle)
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                HotkeyBadge(label: hotkeyLabel ?? type.hotkeyLabel, enabled: enabled)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isHovered && enabled ? 0.07 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Hotkey Badge

struct HotkeyBadge: View {
    let label: String
    let enabled: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(label.components(separatedBy: " + "), id: \.self) { key in
                Text(Self.symbol(for: key))
                    .font(.raycastMono(size: 10.5, weight: .medium))
                    .foregroundStyle(enabled ? .secondary : .tertiary)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 19)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                    )
            }
        }
    }

    /// "fn + Shift" as "fn ⇧", the way macOS menus show shortcuts.
    static func glyphs(for label: String) -> String {
        label.components(separatedBy: " + ").map(symbol(for:)).joined(separator: " ")
    }

    /// Mac keyboard glyphs, as in system menus.
    private static func symbol(for key: String) -> String {
        switch key {
        case "Shift": return "⇧"
        case "Ctrl": return "⌃"
        case "Option": return "⌥"
        case "Cmd": return "⌘"
        default: return key
        }
    }
}
