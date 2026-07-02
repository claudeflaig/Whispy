import SwiftUI

struct WorkflowRowView: View {
    let type: WorkflowType
    let enabled: Bool
    var customName: String? = nil
    var subtitle: String? = nil
    var hotkeyLabel: String? = nil
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(enabled ? 0.22 : 0.06), accent.opacity(enabled ? 0.08 : 0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(accent.opacity(enabled ? 0.24 : 0.06), lineWidth: 0.8)
                        )
                        .shadow(color: accent.opacity(isHovered && enabled ? 0.20 : 0.05), radius: isHovered ? 12 : 5, y: isHovered ? 5 : 2)

                    Image(systemName: type.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(enabled ? accent : Color.secondary.opacity(0.45))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(customName ?? type.displayName)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(enabled ? .primary : .tertiary)
                            .lineLimit(1)

                        if type == .localTranscription {
                            miniPill("LOKAL", color: .green)
                        } else if type == .transcription {
                            miniPill("OPENAI", color: .blue)
                        }
                    }

                    Text(subtitle ?? type.subtitle)
                        .font(.system(size: 10.7, weight: .medium))
                        .foregroundStyle(enabled ? .secondary : .quaternary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Shortcut")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(0.35)
                        .foregroundStyle(enabled ? .tertiary : .quaternary)
                    HotkeyBadge(label: hotkeyLabel ?? type.hotkeyLabel, enabled: enabled, accent: accent)
                        .opacity(enabled ? 1 : 0.35)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(cardStroke, lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(isHovered && enabled ? 0.10 : 0.035), radius: isHovered ? 14 : 7, y: isHovered ? 7 : 3)
            .scaleEffect(isHovered && enabled ? 1.012 : 1.0)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func miniPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 7.8, weight: .black))
            .tracking(0.45)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(Capsule(style: .continuous).fill(color.opacity(0.12)))
    }

    private var accent: Color {
        switch type {
        case .localTranscription: return .green
        case .transcription: return .blue
        case .textImprover: return .purple
        case .dampfAblassen: return .orange
        case .emojiText: return .cyan
        }
    }

    private var cardFill: Color {
        if colorScheme == .dark {
            return Color.white.opacity(isHovered && enabled ? 0.085 : 0.055)
        }
        return Color.white.opacity(isHovered && enabled ? 0.78 : 0.58)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.74)
    }
}

// MARK: - Hotkey Badge

struct HotkeyBadge: View {
    let label: String
    let enabled: Bool
    var accent: Color = .secondary
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 3) {
            ForEach(label.components(separatedBy: " + "), id: \.self) { key in
                Text(key)
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(keyTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(keyBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(keyStrokeColor, lineWidth: 0.8)
                    )
                    .shadow(color: keyShadowColor, radius: 2.0, y: 1)
            }
        }
    }

    private var keyTextColor: Color {
        guard enabled else {
            return colorScheme == .dark ? Color.white.opacity(0.34) : Color.black.opacity(0.26)
        }
        return colorScheme == .dark ? Color.white.opacity(0.90) : Color.black.opacity(0.76)
    }

    private var keyBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                enabled ? accent.opacity(colorScheme == .dark ? 0.22 : 0.12) : Color.primary.opacity(0.035),
                enabled ? Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.045) : Color.primary.opacity(0.025)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var keyStrokeColor: Color {
        guard enabled else { return Color.primary.opacity(0.06) }
        return accent.opacity(colorScheme == .dark ? 0.32 : 0.22)
    }

    private var keyShadowColor: Color {
        guard enabled else { return .clear }
        return accent.opacity(colorScheme == .dark ? 0.10 : 0.08)
    }
}
