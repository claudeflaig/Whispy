import Foundation

/// One dictionary entry: whenever one of the triggers is dictated as a whole word,
/// it is replaced. An empty replacement removes the word, for filler words.
struct TextReplacementRule: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Comma-separated, e.g. "äh, ähm".
    var triggers: String
    var replacement: String = ""
    var isEnabled = true

    var triggerList: [String] {
        triggers
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var removesWord: Bool {
        replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let defaults: [TextReplacementRule] = [
        .init(triggers: "äh, ähm, ähh, öhm, öh"),
        .init(triggers: "hm, hmm, mhm"),
        .init(triggers: "mfg", replacement: "Mit freundlichen Grüßen", isEnabled: false)
    ]
}

enum TextReplacementService {
    static func apply(_ rules: [TextReplacementRule], to text: String) -> String {
        let active = rules.filter { $0.isEnabled && !$0.triggerList.isEmpty }
        guard !active.isEmpty, !text.isEmpty else { return text }

        var result = text
        var removedSomething = false

        for rule in active {
            for trigger in rule.triggerList {
                let escaped = NSRegularExpression.escapedPattern(for: trigger)
                // Lookarounds instead of \b, so triggers may start or end with punctuation
                // and parts of hyphenated compounds ("Hmm-Problem") stay untouched.
                let word = "(?<![\\p{L}\\p{N}-])\(escaped)(?![\\p{L}\\p{N}-])"

                if rule.removesWord {
                    // A filler takes its own trailing comma with it: "Ich, äh, wollte" → "Ich, wollte".
                    guard let regex = try? NSRegularExpression(pattern: "\(word)[,…]*", options: .caseInsensitive) else { continue }
                    let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
                    for match in matches.reversed() {
                        guard let range = Range(match.range, in: result) else { continue }
                        // A capitalised filler opened a sentence; its capital moves on to the next word.
                        let opensSentence = result[range].first?.isUppercase == true
                        let offset = result.distance(from: result.startIndex, to: range.lowerBound)
                        result.removeSubrange(range)
                        let removalPoint = result.index(result.startIndex, offsetBy: offset)
                        if opensSentence,
                           let next = result[removalPoint...].firstIndex(where: \.isLetter),
                           result[next].isLowercase {
                            result.replaceSubrange(next...next, with: result[next].uppercased())
                        }
                        removedSomething = true
                    }
                } else {
                    guard let regex = try? NSRegularExpression(pattern: word, options: .caseInsensitive) else { continue }
                    let range = NSRange(result.startIndex..., in: result)
                    let template = NSRegularExpression.escapedTemplate(for: rule.replacement)
                    result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: template)
                }
            }
        }

        guard removedSomething else { return result }
        return tidiedAfterRemoval(result)
    }

    /// Closes the gaps a removed word leaves behind.
    private static func tidiedAfterRemoval(_ text: String) -> String {
        var result = text
        let fixes: [(String, String)] = [
            ("[ \\t]{2,}", " "),                 // double spaces
            ("[ \\t]+([,.;:!?])", "$1"),         // space before punctuation
            (",\\s*,", ","),                     // doubled commas
            (",\\s*([.;:!?])", "$1"),            // comma right before a sentence mark
            ("(^|[.!?]\\s+|\\n)\\s*,\\s*", "$1"),  // comma opening a sentence
            ("(?m)^[ \\t]+|[ \\t]+$", "")        // stray whitespace at line edges
        ]
        for (pattern, template) in fixes {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: template
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
