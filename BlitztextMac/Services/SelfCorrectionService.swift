import Foundation
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

private let selfCorrectionLogger = Logger(subsystem: "app.claudeflaig.whispy", category: "SelfCorrection")

/// Keeps only what the speaker finally meant when they corrected themselves mid-sentence:
/// "am Montag, nein, am Freitag" becomes "am Freitag". Modelled on FoxSay's Vocal Corrections.
///
/// Local dictations only ever use Apple's on-device model, so nothing leaves the Mac.
/// OpenAI is used only for dictations that already went to OpenAI.
enum SelfCorrectionService {
    /// Phrases people use to correct themselves. The model only runs when one of them was
    /// said, so ordinary dictations are pasted without any extra delay.
    private static let cues = [
        "nein", "ne,", "nee", "ich meine", "ich meinte", "moment", "korrektur", "korrigiere",
        "streich das", "streiche das", "vergiss das", "oder besser", "besser gesagt", "sorry",
        "quatsch", "falsch", "stopp", "halt,", "äh nein", "doch nicht", "lieber doch",
        "scratch that", "i mean", "no wait", "actually", "sorry, i meant"
    ]

    private static let timeout: Duration = .seconds(5)

    static func mightContainCorrection(_ text: String) -> Bool {
        let lowered = " " + text.lowercased() + " "
        return cues.contains { cue in
            lowered.range(of: "(?<![\\p{L}])\(NSRegularExpression.escapedPattern(for: cue))(?![\\p{L}])", options: .regularExpression) != nil
        }
    }

    static var isOnDeviceModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Why the on-device model can't be used, in words for the settings, or nil when it can.
    static var onDeviceUnavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.modelNotReady):
                return "macOS lädt Apples Sprachmodell noch."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence ist ausgeschaltet."
            case .unavailable:
                return "Apples Sprachmodell läuft auf diesem Mac nicht."
            }
        }
        #endif
        return "Apples Sprachmodell braucht macOS 26."
    }

    /// Returns the cleaned text, or the original whenever no model is allowed or available,
    /// the model is slow, or its answer is not a pure deletion of words.
    static func apply(to text: String, allowsCloud: Bool) async -> String {
        guard mightContainCorrection(text) else { return text }

        let started = Date()
        let candidate: String?
        if isOnDeviceModelAvailable {
            candidate = await withTimeout { try await onDevice(text) }
        } else if allowsCloud, KeychainService.isConfigured {
            candidate = await withTimeout { try await LLMService.removeSelfCorrections(text: text, prompt: prompt) }
        } else {
            return text
        }

        let ms = Int(Date().timeIntervalSince(started) * 1000)
        guard let candidate, isPureDeletion(original: text, rewritten: candidate) else {
            selfCorrectionLogger.debug("kept original after \(ms, privacy: .public) ms")
            return text
        }
        selfCorrectionLogger.debug("applied in \(ms, privacy: .public) ms")
        return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A self-correction only ever removes words. Anything else (an answer to a dictated
    /// question, a rephrasing, a translation) is rejected, so the model cannot change
    /// what was said.
    static func isPureDeletion(original: String, rewritten: String) -> Bool {
        let before = words(in: original)
        let after = words(in: rewritten)
        guard !after.isEmpty, after.count < before.count else { return false }

        var available = Dictionary(before.map { ($0, 1) }, uniquingKeysWith: +)
        for word in after {
            guard let count = available[word], count > 0 else { return false }
            available[word] = count - 1
        }
        return true
    }

    private static func words(in text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { word, _, _, _ in
            if let word { result.append(word.lowercased()) }
        }
        return result
    }

    static let prompt = """
        Du bearbeitest Transkripte von gesprochenem Text. Manchmal korrigiert sich die sprechende Person mitten im Satz. \
        Gib den Text so zurück, dass nur übrig bleibt, was sie am Ende gemeint hat: Lösche die verworfenen Wörter \
        und die Korrekturfloskel selbst (zum Beispiel "nein", "ich meine", "streich das"). \
        Lösche nur Wörter. Füge keine Wörter hinzu, formuliere nichts um, übersetze nichts und beantworte keine Fragen aus dem Text. \
        Wenn sich die Person nicht korrigiert hat, gib den Text vollständig unverändert zurück. \
        Gib nur den Text zurück, ohne Anführungszeichen und ohne Erklärung.

        Beispiel 1
        Eingabe: Lass uns am Montag treffen, nein, am Freitag.
        Ausgabe: Lass uns am Freitag treffen.

        Beispiel 2
        Eingabe: Ich bin um fünf, ich meine um sechs Uhr da.
        Ausgabe: Ich bin um sechs Uhr da.

        Beispiel 3
        Eingabe: Nein, das passt mir leider nicht.
        Ausgabe: Nein, das passt mir leider nicht.

        Beispiel 4
        Eingabe: Schick es an Anna, Moment, an Jonas.
        Ausgabe: Schick es an Jonas.
        """

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static func appleModel(_ text: String) async throws -> String {
        let session = LanguageModelSession(instructions: prompt)
        let response = try await session.respond(
            to: "Eingabe: \(text)\nAusgabe:",
            options: GenerationOptions(temperature: 0)
        )
        return response.content
    }
    #endif

    private static func onDevice(_ text: String) async throws -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await appleModel(text)
        }
        #endif
        return nil
    }

    private static func withTimeout(_ operation: @escaping @Sendable () async throws -> String?) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { try? await operation() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
