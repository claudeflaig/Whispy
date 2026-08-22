import AppKit
import SwiftUI

@MainActor
final class RecordingMarkerOverlay {
    private let model = RecordingMarkerModel()
    private var window: NSWindow?
    private var updateTimer: Timer?
    private var audioLevelProvider: (() -> Float)?
    private var transcriptProvider: (() -> String)?
    private var anchorFrame: CGRect?

    func show(
        audioLevelProvider: @escaping () -> Float,
        transcriptProvider: @escaping () -> String = { "" },
        showsLiveTranscript: Bool = false
    ) {
        self.audioLevelProvider = audioLevelProvider
        self.transcriptProvider = transcriptProvider
        self.anchorFrame = Self.focusedElementFrame()
        model.showsLiveTranscript = showsLiveTranscript

        if window == nil {
            let controller = NSHostingController(rootView: RecordingMarkerView(model: model))
            let panel = RecordingMarkerPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 72),
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

        window?.setContentSize(showsLiveTranscript ? NSSize(width: 380, height: 72) : NSSize(width: 86, height: 34))
        updatePosition()
        model.isVisible = true
        window?.orderFrontRegardless()
        startTimer()
    }

    func hide() {
        stopTimer()
        model.isVisible = false
        audioLevelProvider = nil
        transcriptProvider = nil
        model.transcript = ""
        anchorFrame = nil
        window?.orderOut(nil)
    }

    private func startTimer() {
        guard updateTimer == nil else { return }
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.model.audioLevel = self.audioLevelProvider?() ?? 0
                let transcript = self.transcriptProvider?() ?? ""
                if transcript != self.model.transcript {
                    self.model.transcript = transcript
                }
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
    @Published var transcript = ""
    @Published var showsLiveTranscript = false
    @Published var isVisible = false
}

private struct RecordingMarkerView: View {
    @ObservedObject var model: RecordingMarkerModel
    @State private var pulse = false

    @ViewBuilder
    var body: some View {
        if model.showsLiveTranscript {
            liveBody
        } else {
            compactBody
        }
    }

    private var liveBody: some View {
        HStack(spacing: 12) {
            indicator(barCount: 7)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text("WHISPY LIVE")
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .tracking(0.55)
                        .foregroundStyle(Color.white.opacity(0.92))
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                }

                Text(model.transcript.isEmpty ? "Ich höre zu …" : latestTranscriptExcerpt)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(model.transcript.isEmpty ? 0.58 : 0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(width: 240, alignment: .leading)
            }
            .frame(width: 240, alignment: .leading)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .frame(width: 380, height: 72)
        .background(panelBackground(cornerRadius: 20))
        .opacity(model.isVisible ? 1 : 0)
        .onAppear { pulse = true }
    }

    private var compactBody: some View {
        indicator(barCount: 5)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(width: 86, height: 34)
            .background(panelBackground(cornerRadius: 17))
            .opacity(model.isVisible ? 1 : 0)
            .onAppear { pulse = true }
    }

    private func indicator(barCount: Int) -> some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.18 + Double(model.audioLevel) * 0.28))
                    .frame(width: ringSize, height: ringSize)
                    .scaleEffect(pulse ? 1.12 : 0.92)
                    .animation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(Color.red)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: .red.opacity(0.55), radius: 7)
            }
            .frame(width: 30, height: 30)

            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 3, height: barHeight(for: index, count: barCount))
                }
            }
            .frame(height: 28)
        }
        .frame(width: barCount == 7 ? 70 : 62, height: 30, alignment: .leading)
    }

    private var latestTranscriptExcerpt: String {
        let transcript = model.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let maximumCharacters = 42
        guard transcript.count > maximumCharacters else { return transcript }

        let rawSuffix = String(transcript.suffix(maximumCharacters))
        if let firstSpace = rawSuffix.firstIndex(where: { $0.isWhitespace }) {
            let wordsOnly = rawSuffix[rawSuffix.index(after: firstSpace)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return "…\(wordsOnly)"
        }
        return "…\(rawSuffix)"
    }

    private func panelBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.black.opacity(0.80))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.30), radius: 15, y: 6)
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

    private func barHeight(for index: Int, count: Int) -> CGFloat {
        let offsets: [CGFloat] = count == 5
            ? [0.45, 0.72, 1.0, 0.72, 0.45]
            : [0.35, 0.58, 0.82, 1.0, 0.82, 0.58, 0.35]
        let idleWave = CGFloat((index % 2) + 1) * 1.5
        return 5 + idleWave + normalizedLevel * 18 * offsets[index]
    }
}
