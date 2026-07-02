import Foundation

// MARK: - Hotkeys

struct HotkeyCombo: Codable, Hashable {
    var function: Bool
    var capsLock: Bool
    var shift: Bool
    var control: Bool
    var option: Bool
    var command: Bool
    var keyCode: UInt16?
    var keyLabel: String?

    init(
        function: Bool = false,
        capsLock: Bool = false,
        shift: Bool = false,
        control: Bool = false,
        option: Bool = false,
        command: Bool = false,
        keyCode: UInt16? = nil,
        keyLabel: String? = nil
    ) {
        self.function = function
        self.capsLock = capsLock
        self.shift = shift
        self.control = control
        self.option = option
        self.command = command
        self.keyCode = keyCode
        self.keyLabel = keyLabel
    }

    enum CodingKeys: String, CodingKey {
        case function
        case capsLock
        case shift
        case control
        case option
        case command
        case keyCode
        case keyLabel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        function = try container.decodeIfPresent(Bool.self, forKey: .function) ?? false
        capsLock = try container.decodeIfPresent(Bool.self, forKey: .capsLock) ?? false
        shift = try container.decodeIfPresent(Bool.self, forKey: .shift) ?? false
        control = try container.decodeIfPresent(Bool.self, forKey: .control) ?? false
        option = try container.decodeIfPresent(Bool.self, forKey: .option) ?? false
        command = try container.decodeIfPresent(Bool.self, forKey: .command) ?? false
        keyCode = try container.decodeIfPresent(UInt16.self, forKey: .keyCode)
        keyLabel = try container.decodeIfPresent(String.self, forKey: .keyLabel)
    }

    var isEmpty: Bool {
        !function && !capsLock && !shift && !control && !option && !command && keyCode == nil
    }

    var hasKey: Bool {
        keyCode != nil
    }

    var displayLabel: String {
        var parts: [String] = []
        if function { parts.append("fn") }
        if shift { parts.append("Shift") }
        if control { parts.append("Ctrl") }
        if option { parts.append("Option") }
        if command { parts.append("Cmd") }
        if let keyLabel, !keyLabel.isEmpty { parts.append(keyLabel) }
        return parts.isEmpty ? "Nicht gesetzt" : parts.joined(separator: " + ")
    }
}

// MARK: - Workflow Types

enum WorkflowType: String, CaseIterable, Identifiable, Codable {
    case transcription
    case localTranscription
    case textImprover
    case dampfAblassen
    case emojiText

    var id: String { rawValue }

    static var mainMenuCases: [WorkflowType] {
        [.localTranscription, .transcription, .textImprover, .dampfAblassen, .emojiText]
    }

    static var userVisibleHotkeyCases: [WorkflowType] {
        mainMenuCases
    }

    var displayName: String {
        switch self {
        case .transcription: return "Whispy OpenAI"
        case .localTranscription: return "Whispy Lokal"
        case .textImprover: return "Whispy+"
        case .dampfAblassen: return "Whispy $%&!"
        case .emojiText: return "Whispy :)"
        }
    }

    var icon: String {
        switch self {
        case .transcription: return "cloud.fill"
        case .localTranscription: return "lock.shield.fill"
        case .textImprover: return "text.badge.checkmark"
        case .dampfAblassen: return "flame.fill"
        case .emojiText: return "face.smiling"
        }
    }

    var subtitle: String {
        switch self {
        case .transcription: return "OpenAI Whisper. Serverbasiert."
        case .localTranscription: return "Lokales WhisperKit. Kein Server."
        case .textImprover: return "Geschrieben sprechen."
        case .dampfAblassen: return "Frust rein. Entspannt raus."
        case .emojiText: return "Text rein. Emojis dazu."
        }
    }

    var defaultHotkeyCombo: HotkeyCombo {
        switch self {
        case .transcription: return HotkeyCombo(function: true, shift: true)
        case .localTranscription: return HotkeyCombo(function: true)
        case .textImprover: return HotkeyCombo(function: true, control: true)
        case .dampfAblassen: return HotkeyCombo(function: true, option: true)
        case .emojiText: return HotkeyCombo(function: true, command: true)
        }
    }

    var hotkeyLabel: String {
        defaultHotkeyCombo.displayLabel
    }

    var accentColor: String {
        switch self {
        case .transcription: return "blue"
        case .localTranscription: return "green"
        case .textImprover: return "purple"
        case .dampfAblassen: return "orange"
        case .emojiText: return "cyan"
        }
    }
}

// MARK: - Workflow State

enum WorkflowPhase: Equatable {
    case idle
    case running(String)
    case done(String)
    case error(String)

    var isActive: Bool {
        switch self {
        case .idle: return false
        default: return true
        }
    }
}

enum WorkflowLaunchSource: Equatable {
    case manual
    case hotkeyBackground

    var presentsWorkflowPage: Bool {
        switch self {
        case .manual:
            return true
        case .hotkeyBackground:
            return false
        }
    }
}

typealias WorkflowOutputHandler = @MainActor (String) -> Void
typealias WorkflowPhaseChangeHandler = @MainActor (WorkflowPhase) -> Void

// MARK: - Workflow Protocol

@MainActor
protocol Workflow: AnyObject, Observable {
    var type: WorkflowType { get }
    var phase: WorkflowPhase { get set }
    var isRecording: Bool { get }
    var audioLevel: Float { get }
    var onOutput: WorkflowOutputHandler? { get set }
    var onPhaseChange: WorkflowPhaseChangeHandler? { get set }

    func start()
    func stop()
    func reset()
}

// MARK: - App Context & History

struct AppContextRule: Codable, Identifiable, Hashable {
    enum Category: String, Codable, CaseIterable, Identifiable {
        case messages
        case email
        case code
        case notes
        case formal
        case general

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .messages: return "Nachrichten"
            case .email: return "E-Mail"
            case .code: return "Code / AI-Agenten"
            case .notes: return "Notizen"
            case .formal: return "Formell"
            case .general: return "Allgemein"
            }
        }

        var icon: String {
            switch self {
            case .messages: return "bubble.left.and.bubble.right.fill"
            case .email: return "envelope.fill"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .notes: return "note.text"
            case .formal: return "briefcase.fill"
            case .general: return "sparkles"
            }
        }
    }

    enum Style: String, Codable, CaseIterable, Identifiable {
        case natural
        case concise
        case polished
        case formal
        case technical
        case casual

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .natural: return "Natürlich"
            case .concise: return "Kurz & klar"
            case .polished: return "Poliert"
            case .formal: return "Formell"
            case .technical: return "Technisch"
            case .casual: return "Locker"
            }
        }
    }

    var id: Category { category }
    var category: Category
    var style: Style
    var bundleIdentifiers: [String]

    static let defaults: [AppContextRule] = [
        .init(category: .messages, style: .casual, bundleIdentifiers: ["com.apple.MobileSMS", "com.tdesktop.Telegram", "net.whatsapp.WhatsApp", "com.tinyspeck.slackmacgap"]),
        .init(category: .email, style: .polished, bundleIdentifiers: ["com.apple.mail", "com.microsoft.Outlook", "com.superhuman.Superhuman"]),
        .init(category: .code, style: .technical, bundleIdentifiers: ["com.todesktop.230313mzl4w4u92", "com.microsoft.VSCode", "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty"]),
        .init(category: .notes, style: .natural, bundleIdentifiers: ["com.craftdocs.Craft", "md.obsidian", "com.apple.Notes", "notion.id"]),
        .init(category: .formal, style: .formal, bundleIdentifiers: ["com.microsoft.Word", "com.apple.iWork.Pages"]),
        .init(category: .general, style: .natural, bundleIdentifiers: [])
    ]
}

struct DictationHistoryEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var workflowType: WorkflowType
    var workflowName: String
    var bundleIdentifier: String?
    var appName: String?
    var contextCategory: AppContextRule.Category
    var style: AppContextRule.Style
    var originalText: String
    var finalText: String
}

// MARK: - App Settings

struct AppSettings: Codable {
    var hotkeyMode: HotkeyMode = .hold
    var hasSeenOnboarding: Bool = false
    var secureLocalModeEnabled: Bool = false
    var selectedLocalTranscriptionModelName: String = LocalTranscriptionService.recommendedFastModelName
    var hasAutoSelectedFastLocalModel: Bool = false
    var hotkeyCombos: [WorkflowType: HotkeyCombo] = WorkflowType.defaultHotkeyCombos
    var appContextRules: [AppContextRule] = AppContextRule.defaults

    init(
        hotkeyMode: HotkeyMode = .hold,
        hasSeenOnboarding: Bool = false,
        secureLocalModeEnabled: Bool = false,
        selectedLocalTranscriptionModelName: String = LocalTranscriptionService.recommendedFastModelName,
        hasAutoSelectedFastLocalModel: Bool = false,
        hotkeyCombos: [WorkflowType: HotkeyCombo] = WorkflowType.defaultHotkeyCombos,
        appContextRules: [AppContextRule] = AppContextRule.defaults
    ) {
        self.hotkeyMode = hotkeyMode
        self.hasSeenOnboarding = hasSeenOnboarding
        self.secureLocalModeEnabled = secureLocalModeEnabled
        self.selectedLocalTranscriptionModelName = selectedLocalTranscriptionModelName
        self.hasAutoSelectedFastLocalModel = hasAutoSelectedFastLocalModel
        self.hotkeyCombos = WorkflowType.mergedWithDefaults(WorkflowType.removingUnsupportedCapsLock(from: hotkeyCombos))
        self.appContextRules = AppSettings.mergedContextRules(appContextRules)
    }

    enum CodingKeys: String, CodingKey {
        case hotkeyMode
        case hasSeenOnboarding
        case secureLocalModeEnabled
        case selectedLocalTranscriptionModelName
        case hasAutoSelectedFastLocalModel
        case hotkeyCombos
        case appContextRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyMode = try container.decodeIfPresent(HotkeyMode.self, forKey: .hotkeyMode) ?? .hold
        hasSeenOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding) ?? false
        secureLocalModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .secureLocalModeEnabled) ?? false
        selectedLocalTranscriptionModelName = try container.decodeIfPresent(
            String.self,
            forKey: .selectedLocalTranscriptionModelName
        ) ?? LocalTranscriptionService.recommendedFastModelName
        hasAutoSelectedFastLocalModel = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasAutoSelectedFastLocalModel
        ) ?? false
        let decodedHotkeys = try container.decodeIfPresent(
            [WorkflowType: HotkeyCombo].self,
            forKey: .hotkeyCombos
        ) ?? WorkflowType.defaultHotkeyCombos
        hotkeyCombos = WorkflowType.mergedWithDefaults(WorkflowType.removingUnsupportedCapsLock(from: decodedHotkeys))
        appContextRules = AppSettings.mergedContextRules(
            try container.decodeIfPresent([AppContextRule].self, forKey: .appContextRules) ?? AppContextRule.defaults
        )
    }

    static func mergedContextRules(_ rules: [AppContextRule]) -> [AppContextRule] {
        var byCategory = Dictionary(uniqueKeysWithValues: AppContextRule.defaults.map { ($0.category, $0) })
        for rule in rules {
            byCategory[rule.category] = rule
        }
        return AppContextRule.Category.allCases.compactMap { byCategory[$0] }
    }
}

extension WorkflowType {
    static var defaultHotkeyCombos: [WorkflowType: HotkeyCombo] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.defaultHotkeyCombo) })
    }

    static func mergedWithDefaults(_ combos: [WorkflowType: HotkeyCombo]) -> [WorkflowType: HotkeyCombo] {
        var merged = defaultHotkeyCombos
        for (type, combo) in combos {
            merged[type] = combo
        }
        return merged
    }

    static func removingUnsupportedCapsLock(from combos: [WorkflowType: HotkeyCombo]) -> [WorkflowType: HotkeyCombo] {
        var sanitized = combos
        for (type, combo) in combos where combo.capsLock {
            sanitized[type] = defaultHotkeyCombos[type] ?? type.defaultHotkeyCombo
        }
        return sanitized
    }
}

enum TranscriptionBackend: String, Codable {
    case remote
    case local
}

// MARK: - Workflow Settings

struct TranscriptionSettings: Codable {
    var language: String = "de"
}

struct DampfAblassenSettings: Codable {
    var systemPrompt: String = "Du erhältst ein emotional gesprochenes Transkript. Erkenne zuerst das eigentliche Ziel, Anliegen und den wahren Frust der Person. Formuliere daraus eine klare, respektvolle und wirksame Nachricht, mit der die Person ihr Ziel eher erreicht. Bewahre relevante Fakten, konkrete Probleme, Grenzen, Erwartungen und die nötige Dringlichkeit. Entferne Beleidigungen, Drohungen, Sarkasmus, Unterstellungen und unnötige Eskalation. Wenn mehrere Vorwürfe genannt werden, verdichte sie auf die entscheidenden Kernpunkte. Der Ton soll ruhig, menschlich, bestimmt und lösungsorientiert sein. Gib NUR die fertige Nachricht zurück."
    var customName: String = ""
}

struct EmojiTextSettings: Codable {
    var emojiDensity: EmojiDensity = .mittel
    var customName: String = ""

    enum EmojiDensity: String, Codable, CaseIterable, Identifiable {
        case wenig
        case mittel
        case viel

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .wenig: return "Wenig"
            case .mittel: return "Mittel"
            case .viel: return "Viel"
            }
        }
    }
}

struct TextImprovementSettings: Codable {
    var systemPrompt: String = ""
    var customTerms: [String] = []
    var context: String = ""
    var tone: TextTone = .neutral
    var customName: String = ""

    enum TextTone: String, Codable, CaseIterable, Identifiable {
        case formal
        case neutral
        case casual

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .formal: return "Formell"
            case .neutral: return "Neutral"
            case .casual: return "Locker"
            }
        }
    }
}
