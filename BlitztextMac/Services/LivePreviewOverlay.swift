import SwiftUI
import AppKit

@MainActor
final class LivePreviewOverlay {
    private var window: NSWindow?

    func show(text: String, subtitle: String?) {
        let previewText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !previewText.isEmpty else { return }

        let controller = NSHostingController(
            rootView: LivePreviewView(text: previewText, subtitle: subtitle)
        )

        let size = NSSize(width: 360, height: min(160, max(92, 62 + previewText.prefix(180).count / 3)))
        if window == nil {
            let window = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.ignoresMouseEvents = true
            self.window = window
        }

        window?.contentViewController = controller
        window?.setContentSize(size)
        positionWindow(size: size)
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func positionWindow(size: NSSize) {
        let frame = Self.focusedElementFrame()
        let origin: CGPoint

        if let frame {
            origin = Self.previewOrigin(nearAccessibilityFrame: frame, previewSize: size)
        } else {
            let screenFrame = NSScreen.main?.visibleFrame ?? .zero
            origin = CGPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height - 80)
        }

        window?.setFrameOrigin(Self.clamped(origin: origin, size: size))
    }

    private static func previewOrigin(nearAccessibilityFrame frame: CGRect, previewSize: CGSize) -> CGPoint {
        let screen = screen(containingAccessibilityFrame: frame) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        let previewTopY = frame.maxY + 12
        return CGPoint(
            x: frame.midX - previewSize.width / 2,
            y: screenFrame.maxY - previewTopY - previewSize.height
        )
    }

    private static func clamped(origin: CGPoint, size: CGSize) -> CGPoint {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.insetBy(dx: -80, dy: -80).contains(origin) }) ?? NSScreen.main else {
            return origin
        }

        let frame = screen.visibleFrame
        return CGPoint(
            x: min(max(origin.x, frame.minX + 8), frame.maxX - size.width - 8),
            y: min(max(origin.y, frame.minY + 8), frame.maxY - size.height - 8)
        )
    }

    private static func screen(containingAccessibilityFrame frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { screen in
            let topLeftFrame = CGRect(
                x: screen.frame.minX,
                y: screen.frame.minY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return topLeftFrame.contains(center)
        }
    }

    private static func focusedElementFrame() -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedObject: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        ) == .success,
              let focusedElement = focusedObject else {
            return nil
        }

        var positionObject: AnyObject?
        var sizeObject: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXPositionAttribute as CFString,
            &positionObject
        ) == .success,
              AXUIElementCopyAttributeValue(
                focusedElement as! AXUIElement,
                kAXSizeAttribute as CFString,
                &sizeObject
              ) == .success,
              let positionValue = positionObject,
              let sizeValue = sizeObject else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        guard size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: position, size: size)
    }
}

private struct LivePreviewView: View {
    let text: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.green)
                Text("Vorschau")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
        .padding(1)
    }
}
