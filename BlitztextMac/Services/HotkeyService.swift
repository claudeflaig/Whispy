import Cocoa
import Observation

// MARK: - Hotkey Mode

enum HotkeyMode: String, Codable, CaseIterable, Identifiable {
    case hold    // Tasten halten = aufnehmen, loslassen = stoppen
    case toggle  // Einmal drücken = starten, nochmal/Escape = stoppen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hold: return "Halten"
        case .toggle: return "Drücken"
        }
    }

    var description: String {
        switch self {
        case .hold: return "Tasten halten zum Aufnehmen, loslassen zum Stoppen"
        case .toggle: return "Einmal drücken zum Starten, nochmal oder Escape = Stoppen"
        }
    }
}

enum HotkeyEvent {
    case down(WorkflowType)
    case up(WorkflowType)
    case cancel
}

// MARK: - Hotkey Service

@Observable
@MainActor
final class HotkeyService {
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var globalKeyUpMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var activeCombo: WorkflowType?
    private var hotkeyCombos: [WorkflowType: HotkeyCombo] = WorkflowType.defaultHotkeyCombos
    private var currentModifierFlags: NSEvent.ModifierFlags = []
    private var pendingModifierStart: Task<Void, Never>?
    private var pendingModifierType: WorkflowType?

    var onHotkeyEvent: ((HotkeyEvent) -> Void)?

    func configure(hotkeyCombos: [WorkflowType: HotkeyCombo]) {
        let merged = WorkflowType.mergedWithDefaults(hotkeyCombos)
        self.hotkeyCombos = Dictionary(uniqueKeysWithValues: WorkflowType.userVisibleHotkeyCases.map { type in
            (type, merged[type] ?? type.defaultHotkeyCombo)
        })
    }

    func start() {
        guard globalFlagsMonitor == nil else { return }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlags(event) }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlags(event) }
            return event
        }

        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handleKeyDown(event) }
        }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handleKeyDown(event) }
            return event
        }

        globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            Task { @MainActor in self?.handleKeyUp(event) }
        }
        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            Task { @MainActor in self?.handleKeyUp(event) }
            return event
        }
    }

    func stop() {
        if let globalFlagsMonitor { NSEvent.removeMonitor(globalFlagsMonitor) }
        if let localFlagsMonitor { NSEvent.removeMonitor(localFlagsMonitor) }
        if let globalKeyDownMonitor { NSEvent.removeMonitor(globalKeyDownMonitor) }
        if let localKeyDownMonitor { NSEvent.removeMonitor(localKeyDownMonitor) }
        if let globalKeyUpMonitor { NSEvent.removeMonitor(globalKeyUpMonitor) }
        if let localKeyUpMonitor { NSEvent.removeMonitor(localKeyUpMonitor) }

        globalFlagsMonitor = nil
        localFlagsMonitor = nil
        globalKeyDownMonitor = nil
        localKeyDownMonitor = nil
        globalKeyUpMonitor = nil
        localKeyUpMonitor = nil
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags.hotkeyRelevantFlags
        currentModifierFlags = flags

        if let type = workflowType(matchingModifierOnly: flags) {
            if activeCombo == nil {
                if shouldDelayModifierOnlyStart(for: type, flags: flags) {
                    scheduleModifierOnlyStart(for: type, flags: flags)
                } else {
                    cancelPendingModifierStart()
                    startModifierOnlyWorkflow(type)
                }
            }
            return
        }

        cancelPendingModifierStart()

        if let combo = activeCombo,
           let activeHotkey = hotkeyCombos[combo],
           !activeHotkey.hasKey,
           !activeHotkey.matches(flags) {
            activeCombo = nil
            onHotkeyEvent?(.up(combo))
        }
    }

    private func startModifierOnlyWorkflow(_ type: WorkflowType) {
        guard activeCombo == nil else { return }
        activeCombo = type
        onHotkeyEvent?(.down(type))
    }

    private func scheduleModifierOnlyStart(for type: WorkflowType, flags: NSEvent.ModifierFlags) {
        guard pendingModifierType != type else { return }
        cancelPendingModifierStart()
        pendingModifierType = type
        pendingModifierStart = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard let self, !Task.isCancelled, self.activeCombo == nil else { return }
            guard self.currentModifierFlags == flags,
                  let combo = self.hotkeyCombos[type],
                  combo.matches(flags) else { return }
            self.pendingModifierType = nil
            self.pendingModifierStart = nil
            self.startModifierOnlyWorkflow(type)
        }
    }

    private func cancelPendingModifierStart() {
        pendingModifierStart?.cancel()
        pendingModifierStart = nil
        pendingModifierType = nil
    }

    private func shouldDelayModifierOnlyStart(for type: WorkflowType, flags: NSEvent.ModifierFlags) -> Bool {
        guard let baseCombo = hotkeyCombos[type], !baseCombo.hasKey else { return false }
        return hotkeyCombos.contains { candidateType, candidateCombo in
            candidateType != type
                && !candidateCombo.isEmpty
                && !candidateCombo.hasKey
                && candidateCombo.strictlyContainsModifierCombo(baseCombo)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 {
            handleEscape()
            return
        }

        guard let type = workflowType(matchingKeyEvent: event) else { return }
        guard activeCombo == nil else { return }
        activeCombo = type
        onHotkeyEvent?(.down(type))
    }

    private func handleKeyUp(_ event: NSEvent) {
        guard let combo = activeCombo,
              let activeHotkey = hotkeyCombos[combo],
              activeHotkey.hasKey,
              activeHotkey.keyCode == event.keyCode else { return }

        activeCombo = nil
        onHotkeyEvent?(.up(combo))
    }

    private func workflowType(matchingModifierOnly flags: NSEvent.ModifierFlags) -> WorkflowType? {
        for type in WorkflowType.userVisibleHotkeyCases {
            guard let combo = hotkeyCombos[type], !combo.isEmpty, !combo.hasKey else { continue }
            if combo.matches(flags) {
                return type
            }
        }
        return nil
    }

    private func workflowType(matchingKeyEvent event: NSEvent) -> WorkflowType? {
        let flags = event.modifierFlags.hotkeyRelevantFlags
        for type in WorkflowType.userVisibleHotkeyCases {
            guard let combo = hotkeyCombos[type], !combo.isEmpty, combo.hasKey else { continue }
            if combo.matches(flags, keyCode: event.keyCode) {
                return type
            }
        }
        return nil
    }

    private func handleEscape() {
        cancelPendingModifierStart()
        activeCombo = nil
        onHotkeyEvent?(.cancel)
    }
}

// MARK: - Hotkey Combo Helpers

extension NSEvent.ModifierFlags {
    var hotkeyRelevantFlags: NSEvent.ModifierFlags {
        // Caps Lock is intentionally ignored: macOS reports it as a toggle, not a reliable hold modifier.
        intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
    }
}

extension HotkeyCombo {
    init(event: NSEvent) {
        let flags = event.modifierFlags.hotkeyRelevantFlags
        self.init(
            function: flags.contains(.function),
            capsLock: false,
            shift: flags.contains(.shift),
            control: flags.contains(.control),
            option: flags.contains(.option),
            command: flags.contains(.command),
            keyCode: event.keyCode,
            keyLabel: Self.displayLabel(for: event)
        )
    }

    init(modifierFlags flags: NSEvent.ModifierFlags) {
        let normalizedFlags = flags.hotkeyRelevantFlags
        self.init(
            function: normalizedFlags.contains(.function),
            capsLock: false,
            shift: normalizedFlags.contains(.shift),
            control: normalizedFlags.contains(.control),
            option: normalizedFlags.contains(.option),
            command: normalizedFlags.contains(.command)
        )
    }

    func matches(_ flags: NSEvent.ModifierFlags) -> Bool {
        let normalizedFlags = flags.hotkeyRelevantFlags
        return normalizedFlags.contains(.function) == function &&
        false == capsLock &&
        normalizedFlags.contains(.shift) == shift &&
        normalizedFlags.contains(.control) == control &&
        normalizedFlags.contains(.option) == option &&
        normalizedFlags.contains(.command) == command
    }

    func matches(_ flags: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        matches(flags) && self.keyCode == keyCode
    }

    func strictlyContainsModifierCombo(_ other: HotkeyCombo) -> Bool {
        guard !hasKey, !other.hasKey else { return false }
        let containsAll = (!other.function || function)
            && (!other.shift || shift)
            && (!other.control || control)
            && (!other.option || option)
            && (!other.command || command)
        let hasAdditionalModifier = (function && !other.function)
            || (shift && !other.shift)
            || (control && !other.control)
            || (option && !other.option)
            || (command && !other.command)
        return containsAll && hasAdditionalModifier
    }

    static func displayLabel(for event: NSEvent) -> String {
        displayLabel(forKeyCode: event.keyCode, fallback: event.charactersIgnoringModifiers ?? event.characters)
    }

    static func displayLabel(forKeyCode keyCode: UInt16, fallback: String? = nil) -> String {
        switch keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Esc"
        case 63: return "fn"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            let raw = fallback ?? "Taste"
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Taste" : trimmed.uppercased()
        }
    }
}
