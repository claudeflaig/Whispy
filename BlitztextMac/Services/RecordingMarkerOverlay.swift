import AppKit
import SwiftUI

@MainActor
final class RecordingMarkerOverlay {
    private let model = RecordingMarkerModel()
    private var window: NSWindow?
    private var updateTimer: Timer?
    private var audioLevelProvider: (() -> Float)?
    private var anchorFrame: CGRect?

    func show(audioLevelProvider: @escaping () -> Float) {
        self.audioLevelProvider = audioLevelProvider
        self.anchorFrame = Self.focusedElementFrame()

        if window == nil {
            let controller = NSHostingController(rootView: RecordingMarkerView(model: model))
            let panel = RecordingMarkerPanel(
                contentRect: NSRect(x: 0, y: 0, width: 86, height: 34),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = controller
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.level = .statusBar
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
            window = panel
        }

        updatePosition()
        model.isVisible = true
        window?.orderFrontRegardless()
        startTimer()
    }

    func hide() {
        stopTimer()
        model.isVisible = false
        audioLevelProvider = nil
        anchorFrame = nil
        window?.orderOut(nil)
    }

    private func startTimer() {
        guard updateTimer == nil else { return }
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.model.audioLevel = self.audioLevelProvider?() ?? 0
                self.updatePosition()
            }
        }
    }

    private func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updatePosition() {
        guard let window else { return }

        let markerSize = window.frame.size
        let frame = anchorFrame ?? Self.focusedElementFrame()
        let origin: CGPoint

        if let frame {
            origin = Self.markerOrigin(aboveAccessibilityFrame: frame, markerSize: markerSize)
        } else if let screen = NSScreen.main {
            origin = CGPoint(
                x: screen.visibleFrame.midX - markerSize.width / 2,
                y: screen.visibleFrame.maxY - markerSize.height - 20
            )
        } else {
            origin = CGPoint(x: 120, y: 120)
        }

        window.setFrameOrigin(Self.clamped(origin: origin, size: markerSize))
    }

    private static func markerOrigin(aboveAccessibilityFrame frame: CGRect, markerSize: CGSize) -> CGPoint {
        let screen = screen(containingAccessibilityFrame: frame) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero

        // AX element frames are reported in a top-left-oriented screen space. NSWindow
        // placement uses AppKit's bottom-left-oriented screen space, so convert the
        // marker's top edge back into AppKit coordinates.
        let markerTopY = frame.minY - 6
        return CGPoint(
            x: frame.midX - markerSize.width / 2,
            y: screenFrame.maxY - markerTopY - markerSize.height
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
              let positionObject,
              let sizeObject else {
            return nil
        }

        let positionValue = positionObject as! AXValue
        let sizeValue = sizeObject as! AXValue

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size),
              size.width > 0,
              size.height > 0 else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    deinit {
        updateTimer?.invalidate()
    }
}

private final class RecordingMarkerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class RecordingMarkerModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isVisible = false
}

private struct RecordingMarkerView: View {
    @ObservedObject var model: RecordingMarkerModel
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.18 + Double(model.audioLevel) * 0.28))
                    .frame(width: ringSize, height: ringSize)
                    .scaleEffect(pulse ? 1.18 : 0.88)
                    .animation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(Color.red)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: .red.opacity(0.55), radius: 7)
            }

            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.82))
                        .frame(width: 3, height: barHeight(for: index))
                }
            }
            .frame(height: 20)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.black.opacity(0.72))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        )
        .opacity(model.isVisible ? 1 : 0)
        .onAppear { pulse = true }
    }

    private var normalizedLevel: CGFloat {
        max(0.05, min(1, CGFloat(model.audioLevel)))
    }

    private var ringSize: CGFloat {
        16 + normalizedLevel * 10
    }

    private var dotSize: CGFloat {
        8 + normalizedLevel * 6
    }

    private func barHeight(for index: Int) -> CGFloat {
        let offsets: [CGFloat] = [0.45, 0.72, 1.0, 0.72, 0.45]
        let idleWave = CGFloat((index % 2) + 1) * 1.5
        return 5 + idleWave + normalizedLevel * 18 * offsets[index]
    }
}
