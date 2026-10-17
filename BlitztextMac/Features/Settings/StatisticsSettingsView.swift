import SwiftUI
import AppKit

/// Dashboard pane, modelled on FoxSay: totals, an activity grid, streaks, apps and workflows.
struct StatisticsSettingsView: View {
    @Bindable var appState: AppState
    @AppStorage("WhispyStatisticsPeriod") private var period: Period = .month
    @State private var confirmsReset = false

    enum Period: String, CaseIterable, Identifiable {
        case week, month, all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .week: return "7 Tage"
            case .month: return "30 Tage"
            case .all: return "Gesamt"
            }
        }

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }

    private var statistics: DictationStatistics { appState.statistics }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if statistics.isEmpty {
                emptyState
            } else {
                Picker("", selection: $period) {
                    ForEach(Period.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                totalsGrid
                activityCard
                HStack(alignment: .top, spacing: 14) {
                    appsCard
                    workflowsCard
                }
                footer
            }
        }
    }

    // MARK: - Totals

    private var currentTotals: DictationStatistics.Totals {
        guard let days = period.days else { return statistics.totals() }
        return statistics.totals(from: Self.date(daysAgo: days - 1))
    }

    /// The equally long period right before the current one.
    private var previousTotals: DictationStatistics.Totals? {
        guard let days = period.days else { return nil }
        return statistics.totals(from: Self.date(daysAgo: 2 * days - 1), to: Self.date(daysAgo: days))
    }

    private var totalsGrid: some View {
        let current = currentTotals
        let previous = previousTotals
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            StatTile(
                title: "Wörter",
                value: current.words.formatted(.number.locale(.whispyGerman)),
                detail: trendText(current.words, previous?.words),
                systemImage: "text.word.spacing"
            )
            StatTile(
                title: "Diktate",
                value: current.dictations.formatted(.number.locale(.whispyGerman)),
                detail: trendText(current.dictations, previous?.dictations),
                systemImage: "mic"
            )
            StatTile(
                title: "Gespart",
                value: Self.durationText(current.savedSeconds),
                detail: "ggü. Tippen mit 40 WpM",
                systemImage: "hourglass"
            )
            StatTile(
                title: "Sprechtempo",
                value: current.wordsPerMinute.map { "\($0) WpM" } ?? "–",
                detail: current.wordsPerMinute == nil
                    ? "wird ab dem nächsten Diktat gemessen"
                    : "Aufnahmezeit \(Self.durationText(current.recordingSeconds))",
                systemImage: "speedometer"
            )
        }
    }

    private func trendText(_ current: Int, _ previous: Int?) -> String {
        guard let previous else {
            let since = statistics.firstDictationAt.map { $0.formatted(.dateTime.day().month(.abbreviated).year().locale(.whispyGerman)) }
            return since.map { "seit \($0)" } ?? ""
        }
        guard previous > 0 else { return current > 0 ? "neu in diesem Zeitraum" : "keine Diktate" }
        let change = Int((Double(current - previous) / Double(previous) * 100).rounded())
        if change == 0 { return "wie im Zeitraum davor" }
        return "\(change > 0 ? "↑" : "↓") \(abs(change)) % ggü. davor"
    }

    // MARK: - Activity

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aktivität")
                    .font(.raycast(size: 13.5, weight: .semibold))
                Spacer()
                Label("\(Self.dayCount(statistics.currentStreak())) in Folge", systemImage: "flame")
                    .foregroundStyle(statistics.currentStreak() > 0 ? Color.raycastRed : .secondary)
                Text("Rekord: \(Self.dayCount(statistics.longestStreak()))")
                    .foregroundStyle(.secondary)
            }
            .font(.raycast(size: 11, weight: .medium))

            ActivityGrid(statistics: statistics)
                .frame(height: ActivityGrid.height)

            HStack(spacing: 4) {
                let today = statistics.day(for: Date())
                Text("Heute: \(Self.count(today.words, "Wort", "Wörter")) in \(Self.count(today.dictations, "Diktat", "Diktaten"))")
                Spacer()
                Text("Weniger")
                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(ActivityGrid.color(level: level))
                        .frame(width: 10, height: 10)
                }
                Text("Mehr")
            }
            .font(.raycast(size: 10.5))
            .foregroundStyle(.secondary)
        }
        .settingsSection()
    }

    // MARK: - Apps & workflows

    private var appsCard: some View {
        let apps = statistics.topApps(limit: 5)
        let maxWords = max(apps.first?.usage.words ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Meiste Wörter in")
                .font(.raycast(size: 13.5, weight: .semibold))
            if apps.isEmpty {
                Text("Noch keine App erkannt.")
                    .font(.raycast(size: 11))
                    .foregroundStyle(.secondary)
            }
            ForEach(apps, id: \.key) { app in
                BarRow(
                    icon: { AppIconView(bundleIdentifier: app.key) },
                    title: app.usage.name,
                    value: app.usage.words.formatted(.number.locale(.whispyGerman)),
                    fraction: Double(app.usage.words) / Double(maxWords)
                )
            }
        }
        .settingsSection()
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var workflowsCard: some View {
        let rows = WorkflowType.mainMenuCases
            .map { ($0, statistics.workflows[$0.rawValue] ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        let maxCount = max(rows.first?.1 ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Workflows")
                .font(.raycast(size: 13.5, weight: .semibold))
            ForEach(rows, id: \.0) { type, count in
                BarRow(
                    icon: {
                        Image(systemName: type.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    },
                    title: appState.displayName(for: type),
                    value: count.formatted(.number.locale(.whispyGerman)),
                    fraction: Double(count) / Double(maxCount)
                )
            }
        }
        .settingsSection()
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var footer: some View {
        HStack {
            Text("Nur Zahlen, kein Text. Bleibt auf diesem Mac und zählt weiter, wenn du den Verlauf löschst.")
                .font(.raycast(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Statistik zurücksetzen") { confirmsReset = true }
                .glassButtonStyle()
                .font(.raycast(size: 10.5, weight: .medium))
        }
        .padding(.horizontal, 4)
        .confirmationDialog("Statistik zurücksetzen?", isPresented: $confirmsReset) {
            Button("Zurücksetzen", role: .destructive) { appState.resetStatistics() }
        } message: {
            Text("Alle Zahlen und die Serie beginnen wieder bei null. Der Verlauf bleibt erhalten.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("Noch keine Diktate")
                .font(.raycast(size: 14, weight: .semibold))
            Text("Sobald du mit Whispy diktierst, siehst du hier Wörter, gesparte Zeit, dein Sprechtempo und deine Serie.")
                .font(.raycast(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .settingsSection()
    }

    // MARK: - Formatting

    private static func date(daysAgo days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    static func durationText(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        if seconds > 0 && minutes == 0 { return "\(Int(seconds.rounded())) Sek." }
        if minutes < 60 { return "\(minutes) Min." }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) Std." : "\(hours) Std. \(rest) Min."
    }

    static func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value.formatted(.number.locale(.whispyGerman))) \(value == 1 ? singular : plural)"
    }

    static func dayCount(_ days: Int) -> String {
        days == 1 ? "1 Tag" : "\(days) Tage"
    }
}

// MARK: - Pieces

private struct StatTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.raycast(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.raycast(size: 22, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(detail)
                .font(.raycast(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .glassCard(cornerRadius: 18)
    }
}

private struct BarRow<Icon: View>: View {
    @ViewBuilder let icon: Icon
    let title: String
    let value: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                icon.frame(width: 18, height: 18)
                Text(title)
                    .font(.raycast(size: 11.5, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(value)
                    .font(.raycastMono(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.raycastRed.opacity(0.75))
                            .frame(width: max(proxy.size.width * fraction, 4))
                    }
            }
            .frame(height: 4)
        }
    }
}

private struct AppIconView: View {
    let bundleIdentifier: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

/// GitHub-style grid: one column per week, Monday at the top, as many weeks as fit.
private struct ActivityGrid: View {
    let statistics: DictationStatistics

    static let cell: CGFloat = 11
    static let gap: CGFloat = 3
    static let labelWidth: CGFloat = 22
    static let monthLabelHeight: CGFloat = 14
    static var height: CGFloat { monthLabelHeight + 7 * cell + 6 * gap }

    static func level(words: Int) -> Int {
        switch words {
        case 0: return 0
        case 1...100: return 1
        case 101...500: return 2
        case 501...1500: return 3
        default: return 4
        }
    }

    static func color(level: Int) -> Color {
        level == 0
            ? Color.primary.opacity(0.07)
            : Color.raycastRed.opacity([0, 0.3, 0.5, 0.72, 0.95][level])
    }

    var body: some View {
        GeometryReader { proxy in
            let weeks = max(Int((proxy.size.width - Self.labelWidth + Self.gap) / (Self.cell + Self.gap)), 4)
            let grid = statistics.activityGrid(weeks: weeks)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: Self.gap) {
                    Color.clear.frame(height: Self.monthLabelHeight - Self.gap)
                    ForEach(0..<7) { row in
                        Text(["Mo", "", "Mi", "", "Fr", "", "So"][row])
                            .font(.raycast(size: 8.5))
                            .foregroundStyle(.secondary)
                            .frame(height: Self.cell)
                    }
                }
                .frame(width: Self.labelWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    monthLabels(for: grid)
                        .frame(height: Self.monthLabelHeight, alignment: .topLeading)

                    HStack(spacing: Self.gap) {
                        ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: Self.gap) {
                                ForEach(0..<7) { row in
                                    cell(for: week[row])
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for entry: (date: Date, day: DictationStatistics.Day)?) -> some View {
        if let entry {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Self.color(level: Self.level(words: entry.day.words)))
                .frame(width: Self.cell, height: Self.cell)
                .help(tooltip(for: entry))
        } else {
            Color.clear.frame(width: Self.cell, height: Self.cell)
        }
    }

    private func tooltip(for entry: (date: Date, day: DictationStatistics.Day)) -> String {
        let date = entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.whispyGerman))
        guard entry.day.dictations > 0 else { return "\(date): keine Diktate" }
        return "\(date): \(StatisticsSettingsView.count(entry.day.words, "Wort", "Wörter")), \(StatisticsSettingsView.count(entry.day.dictations, "Diktat", "Diktate"))"
    }

    /// Month names above the first week that starts in that month.
    private func monthLabels(for grid: [[(date: Date, day: DictationStatistics.Day)?]]) -> some View {
        let calendar = Calendar.current
        var labels: [(index: Int, title: String)] = []
        var lastMonth: Int?
        for (index, week) in grid.enumerated() {
            guard let date = week.compactMap({ $0?.date }).first else { continue }
            let month = calendar.component(.month, from: date)
            if month != lastMonth {
                if lastMonth != nil || calendar.component(.day, from: date) <= 7 {
                    labels.append((index, date.formatted(.dateTime.month(.abbreviated).locale(.whispyGerman))))
                }
                lastMonth = month
            }
        }

        return ZStack(alignment: .topLeading) {
            ForEach(labels, id: \.index) { label in
                Text(label.title)
                    .font(.raycast(size: 8.5))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(x: CGFloat(label.index) * (Self.cell + Self.gap))
            }
        }
    }
}

extension Locale {
    /// Whispy's interface is German, whatever region the Mac is set to.
    static let whispyGerman = Locale(identifier: "de_DE")
}
