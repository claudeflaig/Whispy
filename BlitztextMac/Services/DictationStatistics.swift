import Foundation

/// Lifetime dictation statistics, kept apart from the history so they keep counting
/// after an entry falls out of the history.
/// Only counts are stored here, never text.
struct DictationStatistics: Codable, Equatable {
    struct Day: Codable, Equatable {
        var dictations: Int = 0
        var words: Int = 0
        var recordingSeconds: Double = 0
    }

    struct AppUsage: Codable, Equatable {
        var name: String
        var dictations: Int = 0
        var words: Int = 0
    }

    var version = 1
    /// Keyed by local calendar day, "yyyy-MM-dd".
    var days: [String: Day] = [:]
    /// Keyed by bundle identifier, or the app name when there is none.
    var apps: [String: AppUsage] = [:]
    /// Keyed by `WorkflowType.rawValue`.
    var workflows: [String: Int] = [:]
    var firstDictationAt: Date?

    /// Someone typing averages about 40 words per minute.
    static let typingWordsPerMinute: Double = 40

    var isEmpty: Bool { days.isEmpty }

    mutating func record(
        words: Int,
        recordingSeconds: Double,
        workflowType: WorkflowType,
        bundleIdentifier: String?,
        appName: String?,
        at date: Date = Date()
    ) {
        let key = Self.dayKey(for: date)
        var day = days[key] ?? Day()
        day.dictations += 1
        day.words += words
        day.recordingSeconds += max(recordingSeconds, 0)
        days[key] = day

        workflows[workflowType.rawValue, default: 0] += 1

        if let appKey = bundleIdentifier ?? appName {
            var usage = apps[appKey] ?? AppUsage(name: appName ?? appKey)
            if let appName { usage.name = appName }
            usage.dictations += 1
            usage.words += words
            apps[appKey] = usage
        }

        if firstDictationAt.map({ date < $0 }) ?? true {
            firstDictationAt = date
        }
    }

    /// Statistics for installs that had a history before statistics existed.
    /// The history carries no recording time, so that part starts at zero.
    static func backfilled(from history: [DictationHistoryEntry]) -> DictationStatistics {
        var statistics = DictationStatistics()
        for entry in history.sorted(by: { $0.createdAt < $1.createdAt }) {
            statistics.record(
                words: wordCount(in: entry.finalText),
                recordingSeconds: 0,
                workflowType: entry.workflowType,
                bundleIdentifier: entry.bundleIdentifier,
                appName: entry.appName,
                at: entry.createdAt
            )
        }
        return statistics
    }

    static func wordCount(in text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }

    // MARK: - Day keys

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    func day(for date: Date) -> Day {
        days[Self.dayKey(for: date)] ?? Day()
    }
}

// MARK: - Summaries for the dashboard

extension DictationStatistics {
    struct Totals {
        var dictations = 0
        var words = 0
        var recordingSeconds: Double = 0

        /// Typing time the dictated words would have taken, minus the time spent speaking.
        var savedSeconds: Double {
            max(Double(words) / DictationStatistics.typingWordsPerMinute * 60 - recordingSeconds, 0)
        }

        /// Only measured where a recording time exists, so backfilled days don't skew it.
        var wordsPerMinute: Int?
    }

    func totals(from start: Date? = nil, to end: Date = Date(), calendar: Calendar = .current) -> Totals {
        let startKey = start.map { Self.dayKey(for: calendar.startOfDay(for: $0)) }
        let endKey = Self.dayKey(for: end)
        var totals = Totals()
        var timedWords = 0
        var timedSeconds: Double = 0

        for (key, day) in days where key <= endKey && (startKey.map { key >= $0 } ?? true) {
            totals.dictations += day.dictations
            totals.words += day.words
            totals.recordingSeconds += day.recordingSeconds
            if day.recordingSeconds > 0 {
                timedWords += day.words
                timedSeconds += day.recordingSeconds
            }
        }

        if timedSeconds >= 5 {
            totals.wordsPerMinute = Int((Double(timedWords) / timedSeconds * 60).rounded())
        }
        return totals
    }

    /// Consecutive days with at least one dictation, ending today (or yesterday, so the
    /// streak doesn't read as broken before the first dictation of the day).
    func currentStreak(today: Date = Date(), calendar: Calendar = .current) -> Int {
        var date = calendar.startOfDay(for: today)
        if days[Self.dayKey(for: date)] == nil {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }
        var streak = 0
        while days[Self.dayKey(for: date)] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return streak
    }

    func longestStreak(calendar: Calendar = .current) -> Int {
        let dates = days.keys.sorted().compactMap { Self.dayFormatter.date(from: $0) }
        var longest = 0
        var current = 0
        var previous: Date?
        for date in dates {
            if let previous,
               let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: date) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = date
        }
        return longest
    }

    /// Weeks as columns, Monday to Sunday as rows, ending with the current week.
    /// Days after `today` are nil.
    func activityGrid(weeks: Int, today: Date = Date(), calendar: Calendar = .current) -> [[(date: Date, day: Day)?]] {
        var calendar = calendar
        calendar.firstWeekday = 2
        let todayStart = calendar.startOfDay(for: today)
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: todayStart)?.start,
              let firstWeek = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeek) else {
            return []
        }

        return (0..<weeks).map { week in
            (0..<7).map { weekday in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + weekday, to: firstWeek),
                      date <= todayStart else { return nil }
                return (date, day(for: date))
            }
        }
    }

    /// `key` is the bundle identifier, or the app name when there was none.
    func topApps(limit: Int) -> [(key: String, usage: AppUsage)] {
        Array(
            apps.map { (key: $0.key, usage: $0.value) }
                .sorted { ($0.usage.words, $0.usage.dictations) > ($1.usage.words, $1.usage.dictations) }
                .prefix(limit)
        )
    }
}
