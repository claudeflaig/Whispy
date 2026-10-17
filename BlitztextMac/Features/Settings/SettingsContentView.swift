import SwiftUI
import AppKit

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case statistics
    case general
    case behavior
    case hotkeys
    case workflows
    case dictionary
    case context
    case history
    case access

    var id: String { rawValue }

    var title: String {
        switch self {
        case .statistics: return "Statistik"
        case .general: return "Transkription"
        case .behavior: return "Verhalten"
        case .hotkeys: return "Tastenkürzel"
        case .workflows: return "Workflows"
        case .dictionary: return "Wörterbuch"
        case .context: return "App-Kontext"
        case .history: return "Verlauf"
        case .access: return "Zugang & System"
        }
    }

    var subtitle: String {
        switch self {
        case .statistics: return "Wie viel du mit Whispy schon diktiert hast."
        case .general: return "Welche Engine deine Stimme in Text verwandelt."
        case .behavior: return "Was beim Aufnehmen und Einfügen passiert."
        case .hotkeys: return "Klicke auf ein Kürzel und drücke die neue Kombination."
        case .workflows: return "Stil und Anweisungen für die KI-Workflows."
        case .dictionary: return "Eigennamen, Ersetzungen und Füllwörter, die verschwinden sollen."
        case .context: return "Whispy passt den Stil an die App an, in die du diktierst."
        case .history: return "Deine letzten \(AppState.historyLimit) Diktate, nur auf diesem Mac."
        case .access: return "Rechte, OpenAI-Key und Installation."
        }
    }

    var icon: String {
        switch self {
        case .statistics: return "chart.bar.xaxis"
        case .general: return "waveform"
        case .behavior: return "slider.horizontal.3"
        case .hotkeys: return "keyboard"
        case .workflows: return "sparkles"
        case .dictionary: return "character.book.closed"
        case .context: return "app.connected.to.app.below.fill"
        case .history: return "clock.arrow.circlepath"
        case .access: return "lock.shield"
        }
    }
}

struct SettingsContentView: View {
    @Bindable var appState: AppState
    // Remembers the last pane; `-WhispySettingsPane hotkeys` at launch opens a given one.
    @AppStorage("WhispySettingsPane") private var selection: SettingsPane = .general

    var body: some View {
        NavigationSplitView {
            List(selection: Binding<SettingsPane?>(
                get: { selection },
                set: { if let pane = $0 { selection = pane } }
            )) {
                ForEach(SettingsPane.allCases) { pane in
                    Label {
                        HStack {
                            Text(pane.title)
                            if pane == .access && !appState.accessibilityPermissionGranted {
                                Spacer()
                                Circle().fill(.orange).frame(width: 7, height: 7)
                            }
                        }
                    } icon: {
                        Image(systemName: pane.icon)
                    }
                    .tag(pane)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selection.title)
                            .font(.raycast(size: 26, weight: .bold))
                        Text(selection.subtitle)
                            .font(.raycast(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    if selection == .access {
                        AccessSettingsView(appState: appState)
                    } else if selection == .statistics {
                        StatisticsSettingsView(appState: appState)
                    } else {
                        CustomizeSettingsView(appState: appState, pane: selection)
                    }
                }
                .frame(maxWidth: 640, alignment: .topLeading)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollContentBackground(.hidden)
            .background(FrostedWindowBackground().ignoresSafeArea())
            .hidingWindowTitle()
        }
        .frame(minWidth: 780, minHeight: 560)
        .onAppear {
            appState.refreshAccessibilityPermission()
            // The orange dot flags missing rights; only a Mac that cannot dictate at all jumps there.
            if !appState.isConfigured {
                selection = .access
            }
        }
    }
}

/// The desktop shows through the detail column, blurred, like Control Center.
private struct FrostedWindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private extension View {
    @ViewBuilder
    func hidingWindowTitle() -> some View {
        if #available(macOS 15.0, *) {
            self.toolbar(removing: .title)
        } else {
            self
        }
    }
}

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.raycast(size: 13.5, weight: .semibold))
            .foregroundStyle(.primary)
    }
}

/// Settings icon tile, like System Settings: a small rounded square.
private struct SettingsIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
    }
}

extension View {
    /// One frosted-glass group in the settings detail column.
    func settingsSection() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 22)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var accent: Color = .blue
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !title.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                SettingsIcon(systemName: systemImage)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.raycast(size: 13.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.raycast(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
            }

            content
        }
        .settingsSection()
    }
}

// MARK: - Access Settings (Tab 1: Zugang)

struct AccessSettingsView: View {
    private static let openAIAPIKeyPattern = #"^sk-[A-Za-z0-9_-]{20,}$"#

    @Bindable var appState: AppState

    private enum FieldFocus {
        case openAIAPIKey
    }

    @State private var launchAtLoginService = LaunchAtLoginService()
    @State private var currentInstallLocation = BlitztextInstallLocationService.currentInstallLocation
    @State private var openAIAPIKey = ""
    @State private var editingAPIKey = false
    @State private var saved = false
    @State private var saveErrorText: String?
    @State private var installActionErrorText: String?
    @State private var showCleanupOptions = false
    @State private var deleteLocalDataOnCleanup = true
    @State private var cleanupStatusText: String?
    @State private var cleanupErrorText: String?
    @FocusState private var focusedField: FieldFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Berechtigungen")

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: appState.accessibilityPermissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.raycast(size: 12, weight: .semibold))
                        .foregroundStyle(appState.accessibilityPermissionGranted ? .green : .orange)
                        .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.accessibilityPermissionGranted ? "Direktes Einfügen ist freigegeben." : "Direktes Einfügen ist noch nicht freigegeben.")
                            .font(.raycast(size: 11.5, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Öffne Bedienungshilfen und aktiviere Whispy. Falls Whispy schon aktiv ist, einmal aus- und wieder einschalten.")
                            .font(.raycast(size: 10.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    Button("Bedienungshilfen öffnen") {
                        appState.requestAccessibilityPermission()
                    }
                    .glassButtonStyle()

                    Button("Erneut prüfen") {
                        appState.refreshAccessibilityPermission()
                    }
                    .glassButtonStyle()
                }
            }
            .settingsSection()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "OpenAI API Key")
                    Spacer()
                    if appState.hasValue(for: .openAIAPIKey) && !editingAPIKey {
                        Button("Ändern") { editingAPIKey = true }
                            .font(.raycast(size: 10, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }

                if appState.hasValue(for: .openAIAPIKey) && !editingAPIKey {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.raycast(size: 9))
                            .foregroundStyle(.secondary)
                        Text(appState.apiKeyDisplayValue(for: .openAIAPIKey))
                            .font(.raycastMono(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                    )
                } else {
                    HStack(spacing: 8) {
                        SecureField("sk-...", text: $openAIAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.raycast(size: 11.5))
                            .focused($focusedField, equals: .openAIAPIKey)

                        Button("Einfuegen") {
                            pasteAPIKeyFromClipboard()
                        }
                        .glassButtonStyle()
                    }
                }

                Text("Dein Key bleibt lokal in dieser App. Audio und Text werden direkt an die OpenAI API gesendet.")
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .settingsSection()

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Installation")

                Text(installationHeadline)
                    .font(.raycast(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(installationDetail)
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(BlitztextInstallLocationService.bundleURL.path)
                    .font(.raycastMono(size: 10.5))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if !BlitztextInstallLocationService.otherInstalledBundleURLs.isEmpty {
                    Text("Weitere Whispy-Kopien auf diesem Mac können doppelte Login-Items auslösen.")
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if BlitztextInstallLocationService.shouldOfferMoveToApplications {
                        Button("Nach /Applications bewegen") {
                            moveToApplications()
                        }
                        .glassButtonStyle()
                    }

                    Button("Im Finder zeigen") {
                        revealInFinder(urls: [BlitztextInstallLocationService.bundleURL])
                    }
                    .glassButtonStyle()

                    if !BlitztextInstallLocationService.otherInstalledBundleURLs.isEmpty {
                        Button("Weitere Kopien zeigen") {
                            revealInFinder(urls: BlitztextInstallLocationService.otherInstalledBundleURLs)
                        }
                        .glassButtonStyle()
                    }
                }

                if let installActionErrorText {
                    Text(installActionErrorText)
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .settingsSection()

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Updates")

                Text("Diese Preview hat keinen oeffentlichen Update-Feed. Baue neue Versionen selbst aus dem Repo.")
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !currentInstallLocation.isCanonicalInstall {
                    Text("Hotkeys und Login-Start laufen am stabilsten, wenn Whispy aus /Applications gestartet wird.")
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Updates sind in dieser Preview manuell: pull, build, starten.")
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .settingsSection()

            // Launch at Login
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Beim Anmelden")

                Toggle("Whispy automatisch starten", isOn: Binding(
                    get: { launchAtLoginService.isEnabled },
                    set: { launchAtLoginService.setEnabled($0) }
                ))
                .toggleStyle(.switch)

                Text(launchAtLoginService.errorText ?? launchAtLoginService.helperText)
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(
                        launchAtLoginService.errorText == nil
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(.red)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .settingsSection()

            if let saveErrorText {
                Text(saveErrorText)
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Hinweis")

                Text("Fuer direktes Einfuegen: Whispy einmal nach /Applications legen und danach Mikrofon sowie Bedienungshilfen erlauben.")
                    .font(.raycast(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                    )
            }
            .settingsSection()

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Sauber Entfernen")

                Text("Vor dem Löschen Whispy erst auf diesem Mac bereinigen. So verschwinden Anmeldestart und lokale Daten sauber aus dem Weg.")
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if showCleanupOptions {
                    Toggle("Zugangsdaten und Einstellungen dieses Macs löschen", isOn: $deleteLocalDataOnCleanup)
                        .toggleStyle(.switch)

                    Text("Danach Whispy beenden und die App aus /Applications löschen. Bereits verwaiste alte Login-Items können in den Systemeinstellungen einmalig manuell entfernt werden.")
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button("Abbrechen") {
                            showCleanupOptions = false
                        }
                        .glassButtonStyle()

                        Button("Jetzt bereinigen") {
                            runCleanup()
                        }
                        .glassButtonStyle()
                        .foregroundStyle(.red)
                    }
                } else {
                    Button("Entfernung vorbereiten") {
                        showCleanupOptions = true
                    }
                    .glassButtonStyle()
                }

                if let cleanupStatusText {
                    Text(cleanupStatusText)
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.green)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let cleanupErrorText {
                    Text(cleanupErrorText)
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .settingsSection()

            // Save button (right-aligned, text only)
            HStack {
                Spacer()
                Button {
                    save()
                } label: {
                    if saved {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.raycast(size: 10, weight: .bold))
                            Text("Gespeichert")
                        }
                        .font(.raycast(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                    } else {
                        Text("Speichern")
                            .font(.raycast(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                .glassButtonStyle()
                .animation(.easeInOut(duration: 0.2), value: saved)
            }
        }
        .onAppear {
            launchAtLoginService.refresh()
            refreshInstallState()
            appState.refreshAccessibilityPermission()
            load()
            if !appState.hasValue(for: .openAIAPIKey) {
                editingAPIKey = true
                focusedField = .openAIAPIKey
            }
        }
    }

    private func load() {
        openAIAPIKey = ""
    }

    private func save() {
        saveErrorText = nil
        cleanupStatusText = nil
        cleanupErrorText = nil
        KeychainService.invalidateCache()
        let trimmedAPIKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if editingAPIKey || !appState.hasValue(for: .openAIAPIKey) {
            guard !trimmedAPIKey.isEmpty else {
                saveErrorText = "Bitte trage deinen OpenAI API Key ein."
                return
            }
            do {
                try KeychainService.save(key: .openAIAPIKey, value: trimmedAPIKey)
                openAIAPIKey = ""
                editingAPIKey = false
            } catch {
                saveErrorText = "OpenAI API Key konnte nicht gespeichert werden."
                return
            }
        }

        KeychainService.invalidateCache()
        if !appState.hasValue(for: .openAIAPIKey) {
            saveErrorText = "OpenAI API Key wurde nicht persistent gespeichert. Bitte App neu starten und erneut versuchen."
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) { saved = false }
        }
    }

    private func pasteAPIKeyFromClipboard() {
        guard let rawText = NSPasteboard.general.string(forType: .string) else {
            saveErrorText = "Zwischenablage enthält keinen Text."
            return
        }

        let firstLine = rawText.components(separatedBy: .newlines).first ?? rawText
        let trimmedKey = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey.range(of: Self.openAIAPIKeyPattern, options: .regularExpression) != nil else {
            saveErrorText = "Zwischenablage enthält keinen plausiblen OpenAI API Key."
            return
        }

        openAIAPIKey = trimmedKey
        NSPasteboard.general.clearContents()
        saveErrorText = nil
    }

    private var installationHeadline: String {
        switch currentInstallLocation {
        case .applications:
            return "Whispy liegt am richtigen Ort."
        case .userApplications:
            return "Whispy liegt noch in ~/Applications."
        case .outsideApplications:
            return "Whispy liegt noch nicht in /Applications."
        case .unknown:
            return "Der Installationsort konnte nicht sicher erkannt werden."
        }
    }

    private var installationDetail: String {
        switch currentInstallLocation {
        case .applications:
            if BlitztextInstallLocationService.otherInstalledBundleURLs.isEmpty {
                return "Für stabile Login-Items und Updates nur diese Kopie weiterverwenden."
            }
            return "Diese Kopie ist korrekt. Zusätzliche Kopien solltest du später entfernen."
        case .userApplications:
            return "Fuer stabile Hotkeys und Login-Items sollte Whispy nur aus /Applications laufen."
        case .outsideApplications:
            return "Verschiebe Whispy einmal nach /Applications, damit Anmeldestart und Hotkeys sauber bleiben."
        case .unknown:
            return "Öffne Whispy möglichst direkt aus /Applications."
        }
    }

    private func refreshInstallState() {
        currentInstallLocation = BlitztextInstallLocationService.currentInstallLocation
        installActionErrorText = nil
    }

    private func moveToApplications() {
        installActionErrorText = nil

        do {
            try BlitztextInstallLocationService.moveToApplicationsAndRelaunch()
        } catch {
            installActionErrorText = error.localizedDescription
        }
    }

    private func runCleanup() {
        cleanupStatusText = nil
        cleanupErrorText = nil

        let report = deleteLocalDataOnCleanup
            ? BlitztextCleanupService.cleanupUserData()
            : BlitztextCleanupService.removeLaunchAtLoginRegistration()

        KeychainService.invalidateCache()
        launchAtLoginService.refresh()
        refreshInstallState()

        if deleteLocalDataOnCleanup {
            openAIAPIKey = ""
            editingAPIKey = true
        }

        if report.failedItems.isEmpty {
            cleanupStatusText = deleteLocalDataOnCleanup
                ? "Anmeldestart und lokale Daten wurden bereinigt. Jetzt Whispy beenden und aus /Applications löschen."
                : "Anmeldestart wurde deaktiviert. Jetzt Whispy beenden und aus /Applications löschen."
            showCleanupOptions = false

            let urlsToReveal = report.knownInstallBundleURLs.isEmpty
                ? [BlitztextInstallLocationService.bundleURL]
                : report.knownInstallBundleURLs
            revealInFinder(urls: urlsToReveal)
            return
        }

        let failureSummary = report.failedItems
            .map { "\($0.url.lastPathComponent): \($0.errorDescription)" }
            .joined(separator: "\n")
        cleanupErrorText = "Nicht alles konnte bereinigt werden:\n\(failureSummary)"
    }

    private func revealInFinder(urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

// MARK: - Customize Settings (Tab 2: Anpassen)

struct CustomizeSettingsView: View {
    @Bindable var appState: AppState
    var pane: SettingsPane = .general
    @State private var historySearch = ""
    @State private var newTerm = ""
    @State private var availableAppOptions: [AppContextAppOption] = AppContextAppOption.defaultOptions

    private var installedLocalModels: [LocalTranscriptionModel] {
        LocalTranscriptionService.installedModels()
    }

    private var localModelOptions: [LocalTranscriptionModel] {
        LocalTranscriptionService.modelOptions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            if pane == .general {
// MARK: Lokaler Modus
            VStack(alignment: .leading, spacing: 10) {
                behaviorToggle(
                    "Sicherer Lokaler Modus",
                    detail: "Diktate bleiben auf diesem Mac. Kein Audio verlässt das Gerät.",
                    isOn: $appState.appSettings.secureLocalModeEnabled
                )
                    .onChange(of: appState.appSettings.secureLocalModeEnabled) { _, newValue in
                        if newValue {
                            appState.enableSecureLocalMode()
                        }
                    }

                Divider().opacity(0.5)

                HStack(spacing: 8) {
                    Text("Lokale Engine")
                        .font(.raycast(size: 12.5, weight: .semibold))

                    Spacer()

                    Picker("", selection: $appState.appSettings.selectedLocalTranscriptionEngine) {
                        ForEach(appState.availableLocalTranscriptionEngines) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                if appState.effectiveLocalTranscriptionEngine == .appleSpeech {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "apple.intelligence")
                            .font(.raycast(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Apple Speech · Echtzeit")
                                .font(.raycast(size: 11.5, weight: .semibold))
                            Text("SpeechAnalyzer transkribiert vollständig lokal und zeigt Wörter bereits während des Sprechens in der Hotbox. macOS verwaltet das Sprachmodell automatisch.")
                                .font(.raycast(size: 10.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if appState.effectiveLocalTranscriptionEngine == .parakeet {
                    parakeetSection
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: appState.selectedLocalModelIsInstalled ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.raycast(size: 11, weight: .semibold))
                            .foregroundStyle(appState.selectedLocalModelIsInstalled ? .green : .blue)
                        Text(appState.selectedLocalModelIsInstalled ? "\(installedLocalModels.count) lokale\(installedLocalModels.count == 1 ? "s" : "") WhisperKit-Modell\(installedLocalModels.count == 1 ? "" : "e") installiert." : "Das ausgewählte Modell wird beim Installieren lokal gespeichert.")
                            .font(.raycast(size: 10.5))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Text("Whisper-Modell")
                            .font(.raycast(size: 11))
                            .foregroundStyle(.secondary)

                        Picker("", selection: Binding(
                            get: { appState.selectedLocalModelName },
                            set: { appState.appSettings.selectedLocalTranscriptionModelName = $0 }
                        )) {
                            ForEach(localModelOptions) { model in
                                Text([model.displayName, model.sizeLabel, model.installStateLabel].compactMap { $0 }.joined(separator: " · ")).tag(model.id)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .disabled(appState.isDownloadingLocalModel)
                    }

                    if let progress = appState.localModelDownloadProgress {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: progress)
                            Text(appState.localModelDownloadStatusText ?? "Modell wird geladen...")
                                .font(.raycast(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 10) {
                            Button(appState.localModelDownloadButtonTitle) {
                                appState.installSelectedLocalModel()
                            }
                            .controlSize(.small)
                            .disabled(appState.selectedLocalModelIsInstalled)

                            Link("Modellseite", destination: LocalTranscriptionService.modelPageURL(for: appState.selectedLocalModelName))
                                .font(.raycast(size: 10.5, weight: .medium))
                        }
                    }

                    if let errorText = appState.localModelDownloadErrorText {
                        Text(errorText)
                            .font(.raycast(size: 10.5))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .settingsSection()
            }

            if pane == .context {
// MARK: App-Kontext
            SettingsCard(
                title: "",
                subtitle: nil,
                systemImage: "app.connected.to.app.below.fill",
                accent: .green
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(AppContextRule.Category.allCases) { category in
                        if category != AppContextRule.Category.allCases.first {
                            Divider().opacity(0.5)
                        }
                        AppContextRuleRow(rule: appContextRuleBinding(for: category), availableApps: availableAppOptions)
                    }
                }
            }
            }

            if pane == .history {
// MARK: Verlauf
            SettingsCard(
                title: "",
                subtitle: nil,
                systemImage: "clock.arrow.circlepath",
                accent: .blue
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    if appState.dictationHistory.isEmpty {
                        Text("Noch keine Diktate im Verlauf.")
                            .font(.raycast(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("Verlauf durchsuchen", text: $historySearch)
                            .textFieldStyle(.roundedBorder)

                        ForEach(filteredHistory) { entry in
                            if entry.id != filteredHistory.first?.id {
                                Divider().opacity(0.5)
                            }
                            HistoryEntryRow(entry: entry) {
                                appState.copyToClipboard(entry.finalText)
                            } pasteAction: {
                                appState.pasteHistoryEntry(entry)
                            }
                        }

                        HStack {
                            Text("Es werden maximal \(AppState.historyLimit) Einträge gespeichert.")
                                .font(.raycast(size: 10.5))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Verlauf löschen") {
                                appState.clearDictationHistory()
                            }
                            .glassButtonStyle()
                            .font(.raycast(size: 10.5, weight: .medium))
                        }
                    }
                }
            }
            }

            if pane == .hotkeys {
// MARK: Tastenkuerzel
            SettingsCard(
                title: "",
                subtitle: nil,
                systemImage: "keyboard",
                accent: .purple
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.raycast(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                        Text("Du kannst lokal und OpenAI parallel verwenden. Weise z.B. \"Whispy Lokal\" fn zu und \"Whispy OpenAI\" fn + Shift.")
                            .font(.raycast(size: 10.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.035))
                    )

                    ForEach(WorkflowType.userVisibleHotkeyCases) { type in
                        if type != WorkflowType.userVisibleHotkeyCases.first {
                            Divider().opacity(0.5)
                        }
                        HotkeyWorkflowRow(
                            title: appState.displayName(for: type),
                            subtitle: appState.workflowSubtitle(for: type),
                            icon: type.icon,
                            accent: workflowAccentColor(type),
                            combo: hotkeyComboBinding(for: type),
                            hotkeyLabel: appState.hotkeyLabel(for: type)
                        )
                    }
                }

                if !hotkeyValidationMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(hotkeyValidationMessages, id: \.self) { message in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.raycast(size: 10, weight: .semibold))
                                Text(message)
                                    .font(.raycast(size: 10.5))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.orange)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Aufnahmemodus")
                            .font(.raycast(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Picker("", selection: $appState.appSettings.hotkeyMode) {
                            ForEach(HotkeyMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Spacer(minLength: 8)

                    Button {
                        let defaults = WorkflowType.defaultHotkeyCombos
                        appState.appSettings.hotkeyCombos = Dictionary(uniqueKeysWithValues: WorkflowType.userVisibleHotkeyCases.map { type in
                            (type, defaults[type] ?? type.defaultHotkeyCombo)
                        })
                    } label: {
                        Label("Zurücksetzen", systemImage: "arrow.counterclockwise")
                            .font(.raycast(size: 11, weight: .medium))
                    }
                    .glassButtonStyle()
                }
            }
            }

            if pane == .workflows {
// MARK: Whispy+
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Whispy+")

                // Tone
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schreibstil")
                        .font(.raycast(size: 11))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $appState.textImprovementSettings.tone) {
                        ForEach(TextImprovementSettings.TextTone.allCases) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // System Prompt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Eigene Anweisung")
                        .font(.raycast(size: 11))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $appState.textImprovementSettings.systemPrompt)
                        .font(.raycast(size: 11))
                        .frame(height: 64)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
                        .overlay(alignment: .topLeading) {
                            if appState.textImprovementSettings.systemPrompt.isEmpty {
                                Text("z.B. \"Schreibe pr\u{00E4}gnant und ohne F\u{00FC}llw\u{00F6}rter.\"")
                                    .font(.raycast(size: 11))
                                    .foregroundStyle(.quaternary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                // Context
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kontext")
                        .font(.raycast(size: 11))
                        .foregroundStyle(.secondary)

                    TextField("z.B. \"E-Mails im Bereich Unternehmensberatung\"", text: $appState.textImprovementSettings.context)
                        .textFieldStyle(.roundedBorder)
                        .font(.raycast(size: 11))
                }
            }
            .settingsSection()

            // MARK: Whispy $%&!
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Whispy $%&!")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Eigene Anweisung")
                        .font(.raycast(size: 11))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $appState.dampfAblassenSettings.systemPrompt)
                        .font(.raycast(size: 11))
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
                        .overlay(alignment: .topLeading) {
                            if appState.dampfAblassenSettings.systemPrompt.isEmpty {
                                Text("z.B. \"Formuliere den Text sachlich und freundlich um.\"")
                                    .font(.raycast(size: 11))
                                    .foregroundStyle(.quaternary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .settingsSection()

            // MARK: Whispy :)
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Whispy :)")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Emoji-Dichte")
                        .font(.raycast(size: 11))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $appState.emojiTextSettings.emojiDensity) {
                        ForEach(EmojiTextSettings.EmojiDensity.allCases) { density in
                            Text(density.displayName).tag(density)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .settingsSection()
            }

            if pane == .dictionary {
            // MARK: Eigennamen
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Eigennamen")
                Text("Hilft der Erkennung bei Namen und Fachbegriffen, die sie sonst falsch schreibt.")
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.secondary)

                // Term chips
                if !appState.textImprovementSettings.customTerms.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(appState.textImprovementSettings.customTerms, id: \.self) { term in
                            HStack(spacing: 3) {
                                Text(term)
                                    .font(.raycast(size: 10.5))
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        appState.textImprovementSettings.customTerms.removeAll { $0 == term }
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.raycast(size: 7, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(SubtleButtonStyle())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
                            )
                        }
                    }
                }

                HStack(spacing: 6) {
                    TextField("Neuer Begriff", text: $newTerm)
                        .textFieldStyle(.roundedBorder)
                        .font(.raycast(size: 11))
                        .onSubmit { addTerm() }

                    Button { addTerm() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.raycast(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(SubtleButtonStyle())
                    .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .settingsSection()

            ReplacementRulesSection(rules: $appState.appSettings.textReplacementRules)
            }

            if pane == .behavior {
                behaviorSection
            }
        }
        .onAppear {
            availableAppOptions = AppContextAppOption.availableOptions()
        }
    }

    private func workflowAccentColor(_ type: WorkflowType) -> Color { .secondary }

    private var parakeetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.raycast(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(ParakeetTranscriptionService.displayName) · Neural Engine")
                        .font(.raycast(size: 11.5, weight: .semibold))
                    Text("NVIDIAs Parakeet in der nachtrainierten Ultra-Fassung, 25 europäische Sprachen. Für Deutsch so genau wie Whisper Large v3, aber ein Vielfaches schneller. Transkribiert nach dem Loslassen, ohne Live-Vorschau.")
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let progress = appState.localModelDownloadProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                    Text(appState.localModelDownloadStatusText ?? "Modell wird geladen...")
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 10) {
                    Button(ParakeetTranscriptionService.isInstalled
                           ? "\(ParakeetTranscriptionService.displayName) ist installiert"
                           : "\(ParakeetTranscriptionService.displayName) installieren (\(ParakeetTranscriptionService.downloadSizeLabel))") {
                        appState.installParakeetModel()
                    }
                    .controlSize(.small)
                    .disabled(ParakeetTranscriptionService.isInstalled)

                    Link("Modellseite", destination: ParakeetTranscriptionService.modelPageURL)
                        .font(.raycast(size: 10.5, weight: .medium))
                }
                if let status = appState.localModelDownloadStatusText {
                    Text(status)
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }

            if let errorText = appState.localModelDownloadErrorText {
                Text(errorText)
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var filteredHistory: [DictationHistoryEntry] {
        let query = historySearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return appState.dictationHistory }
        return appState.dictationHistory.filter {
            $0.finalText.localizedCaseInsensitiveContains(query)
                || ($0.appName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(
                title: "Einfügen",
                subtitle: "Was nach dem Diktat im Ziel-Textfeld passiert.",
                systemImage: "text.cursor"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    behaviorToggle(
                        "Zwischenablage wiederherstellen",
                        detail: "Nach dem Einfügen liegt wieder das in der Zwischenablage, was du vorher kopiert hattest.",
                        isOn: $appState.appSettings.restoresClipboard
                    )
                    behaviorToggle(
                        "Leerzeichen anhängen",
                        detail: "Damit der nächste Satz direkt anschließt.",
                        isOn: $appState.appSettings.appendsTrailingSpace
                    )
                    behaviorToggle(
                        "Selbstkorrekturen glätten",
                        detail: "Sagst du „am Montag, nein, am Freitag“, wird nur „am Freitag“ eingefügt. "
                            + (SelfCorrectionService.onDeviceUnavailableReason.map {
                                "\($0) Bis dahin wirkt es nur bei OpenAI-Diktaten, lokale Diktate bleiben unverändert."
                            } ?? "Läuft mit Apples Sprachmodell auf diesem Mac und nur, wenn du dich hörbar korrigierst."),
                        isOn: $appState.appSettings.removesSelfCorrections
                    )
                    behaviorToggle(
                        "Automatisch senden",
                        detail: "Drückt nach dem Einfügen Return, etwa in Chats oder bei AI-Agenten.",
                        isOn: $appState.appSettings.autoSubmitsAfterPaste
                    )
                }
            }

            SettingsCard(
                title: "Aufnahme",
                subtitle: "Esc verwirft eine laufende Aufnahme, ohne etwas einzufügen.",
                systemImage: "mic"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    behaviorToggle(
                        "Töne bei Start und Stopp",
                        detail: "Ein leiser Ton bestätigt, dass Whispy zuhört oder fertig ist.",
                        isOn: $appState.appSettings.playsFeedbackSounds
                    )
                    behaviorToggle(
                        "Systemton während der Aufnahme stummschalten",
                        detail: "Musik und Videos landen nicht im Diktat. Danach wird der Ton wieder eingeschaltet.",
                        isOn: $appState.appSettings.mutesSystemAudioWhileRecording
                    )
                }
            }
        }
    }

    private func behaviorToggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.raycast(size: 12.5, weight: .semibold))
                Text(detail)
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
    }

    private func appContextRuleBinding(for category: AppContextRule.Category) -> Binding<AppContextRule> {
        Binding(
            get: {
                appState.appSettings.appContextRules.first { $0.category == category }
                    ?? AppContextRule.defaults.first { $0.category == category }
                    ?? AppContextRule(category: category, style: .natural, bundleIdentifiers: [])
            },
            set: { newValue in
                var rules = appState.appSettings.appContextRules
                if let index = rules.firstIndex(where: { $0.category == category }) {
                    rules[index] = newValue
                } else {
                    rules.append(newValue)
                }
                appState.appSettings.appContextRules = AppSettings.mergedContextRules(rules)
            }
        )
    }

    private func hotkeyComboBinding(for type: WorkflowType) -> Binding<HotkeyCombo> {
        Binding(
            get: {
                appState.appSettings.hotkeyCombos[type] ?? type.defaultHotkeyCombo
            },
            set: { newValue in
                appState.appSettings.hotkeyCombos[type] = newValue
            }
        )
    }

    private var hotkeyValidationMessages: [String] {
        var messages: [String] = []
        let combos = WorkflowType.userVisibleHotkeyCases.map { type in
            (type, appState.appSettings.hotkeyCombos[type] ?? type.defaultHotkeyCombo)
        }

        for (type, combo) in combos where combo.isEmpty {
            messages.append("\(appState.displayName(for: type)) hat kein Tastenkürzel.")
        }

        let grouped = Dictionary(grouping: combos.filter { !$0.1.isEmpty }, by: { $0.1 })
        for (_, entries) in grouped where entries.count > 1 {
            let names = entries.map { appState.displayName(for: $0.0) }.joined(separator: ", ")
            messages.append("Doppeltes Tastenkürzel für: \(names).")
        }

        return messages
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !appState.textImprovementSettings.customTerms.contains(trimmed) else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            appState.textImprovementSettings.customTerms.append(trimmed)
        }
        newTerm = ""
    }
}


private struct AppContextAppOption: Identifiable, Hashable {
    let name: String
    let bundleIdentifier: String

    var id: String { bundleIdentifier }

    static let defaultOptions: [AppContextAppOption] = [
        .init(name: "Mail", bundleIdentifier: "com.apple.mail"),
        .init(name: "Nachrichten", bundleIdentifier: "com.apple.MobileSMS"),
        .init(name: "Safari", bundleIdentifier: "com.apple.Safari"),
        .init(name: "Notizen", bundleIdentifier: "com.apple.Notes"),
        .init(name: "Pages", bundleIdentifier: "com.apple.iWork.Pages"),
        .init(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"),
        .init(name: "WhatsApp", bundleIdentifier: "net.whatsapp.WhatsApp"),
        .init(name: "Telegram", bundleIdentifier: "ru.keepcoder.Telegram"),
        .init(name: "Microsoft Outlook", bundleIdentifier: "com.microsoft.Outlook"),
        .init(name: "Microsoft Word", bundleIdentifier: "com.microsoft.Word"),
        .init(name: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode"),
        .init(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
        .init(name: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92"),
        .init(name: "Craft", bundleIdentifier: "com.lukilabs.lukiapp"),
        .init(name: "Arc", bundleIdentifier: "company.thebrowser.Browser")
    ]

    static func icon(for bundleIdentifier: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
    }

    /// The app's display name, or the last part of the bundle ID when it is not installed.
    static func name(for bundleIdentifier: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let bundle = Bundle(url: url) {
            return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
        }
        return bundleIdentifier.split(separator: ".").last.map { $0.capitalized } ?? bundleIdentifier
    }

    static func availableOptions() -> [AppContextAppOption] {
        var options = defaultOptions
        let applicationDirectories = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        for directory in applicationDirectories {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: directory),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { continue }
                let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                options.append(.init(name: displayName, bundleIdentifier: identifier))
            }
        }

        return Array(Dictionary(grouping: options, by: \.bundleIdentifier).compactMap { $0.value.first })
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct AppContextRuleRow: View {
    @Binding var rule: AppContextRule
    let availableApps: [AppContextAppOption]

    private var selectedApps: [AppContextAppOption] {
        rule.bundleIdentifiers.map { identifier in
            availableApps.first { $0.bundleIdentifier == identifier }
                ?? AppContextAppOption(name: AppContextAppOption.name(for: identifier), bundleIdentifier: identifier)
        }
    }

    private var remainingApps: [AppContextAppOption] {
        availableApps.filter { !rule.bundleIdentifiers.contains($0.bundleIdentifier) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SettingsIcon(systemName: rule.category.icon)

                Text(rule.category.displayName)
                    .font(.raycast(size: 13, weight: .semibold))

                Spacer()

                Picker("", selection: $rule.style) {
                    ForEach(AppContextRule.Style.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
                .controlSize(.small)
            }

            if selectedApps.isEmpty {
                Text("Keine Apps zugeordnet.")
                    .font(.raycast(size: 10.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(selectedApps) { app in
                        HStack(spacing: 5) {
                            Image(nsImage: AppContextAppOption.icon(for: app.bundleIdentifier))
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(app.name)
                                .font(.raycast(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                            Button {
                                rule.bundleIdentifiers.removeAll { $0 == app.bundleIdentifier }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.raycast(size: 7.5, weight: .black))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(SubtleButtonStyle())
                        }
                        .padding(.leading, 5)
                        .padding(.trailing, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.07))
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(remainingApps.prefix(80)) { app in
                        Button(app.name) {
                            rule.bundleIdentifiers.append(app.bundleIdentifier)
                        }
                    }
                } label: {
                    Label("App hinzufügen", systemImage: "plus.circle.fill")
                        .font(.raycast(size: 11, weight: .semibold))
                }
                .menuStyle(.button)
                .controlSize(.small)

                if !rule.bundleIdentifiers.isEmpty {
                    Button("Alle entfernen") {
                        rule.bundleIdentifiers.removeAll()
                    }
                    .font(.raycast(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .buttonStyle(SubtleButtonStyle())
                }

                Spacer()

                Text("\(rule.bundleIdentifiers.count) Apps")
                    .font(.raycast(size: 9.5, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct HistoryEntryRow: View {
    let entry: DictationHistoryEntry
    let copyAction: () -> Void
    let pasteAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SettingsIcon(systemName: entry.workflowType.icon)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.workflowName)
                        .font(.raycast(size: 11.5, weight: .bold))
                    Text(entry.contextCategory.displayName)
                        .font(.raycast(size: 8.5, weight: .black))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.055)))
                    if let appName = entry.appName {
                        Text(appName)
                            .font(.raycast(size: 9.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(entry.finalText)
                    .font(.raycast(size: 10.8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button(action: copyAction) {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 16, height: 16)
                }
                .help("Kopieren")
                .glassIconButtonStyle()
                Button(action: pasteAction) {
                    Image(systemName: "arrow.turn.down.left")
                        .frame(width: 16, height: 16)
                }
                .help("Einfügen")
                .glassIconButtonStyle()
            }
        }
        .padding(.vertical, 6)
    }
}

private struct HotkeyWorkflowRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    @Binding var combo: HotkeyCombo
    let hotkeyLabel: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.raycast(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.raycast(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            HotkeyComboPicker(combo: $combo, title: hotkeyLabel)
        }
        .padding(.vertical, 4)
    }
}

private struct HotkeyComboPicker: View {
    @Binding var combo: HotkeyCombo
    let title: String

    @State private var isRecording = false
    @State private var localFlagsMonitor: Any?
    @State private var localKeyDownMonitor: Any?
    @State private var pendingModifierSave: DispatchWorkItem?
    @State private var recordedFunction = false
    @State private var recordedCapsLock = false
    @State private var recordedShift = false
    @State private var recordedControl = false
    @State private var recordedOption = false
    @State private var recordedCommand = false

    var body: some View {
        HStack(spacing: 5) {
            Button {
                startRecording()
            } label: {
                HStack(spacing: 6) {
                    if isRecording {
                        Image(systemName: "record.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .symbolEffect(.pulse)
                    }
                    Text(isRecording ? "Kombination drücken …" : HotkeyBadge.glyphs(for: title))
                        .font(.raycastMono(size: 11, weight: .medium))
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minWidth: 150, alignment: .center)
                .background(
                    Capsule(style: .continuous)
                        .fill(isRecording ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.07))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 0.8)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(SubtleButtonStyle())
            .fixedSize(horizontal: true, vertical: false)

            Button {
                combo = HotkeyCombo()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(combo.isEmpty ? .quaternary : .tertiary)
            }
            .buttonStyle(SubtleButtonStyle())
            .disabled(combo.isEmpty)
            .help("Kürzel löschen")
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var labelColor: Color {
        if isRecording { return .accentColor }
        return combo.isEmpty ? .orange : .primary
    }

    private var borderColor: Color {
        if isRecording { return .accentColor.opacity(0.6) }
        return combo.isEmpty ? .orange.opacity(0.5) : .primary.opacity(0.08)
    }

    private func startRecording() {
        stopRecording()
        resetRecordedModifiers()
        isRecording = true

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            updateRecordedModifiers(from: event)
            scheduleModifierOnlySave()
            return nil
        }

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape cancels recording
                stopRecording()
                return nil
            }

            pendingModifierSave?.cancel()
            combo = HotkeyCombo(event: event)
            stopRecording()
            return nil
        }
    }

    private func updateRecordedModifiers(from event: NSEvent) {
        let flags = event.modifierFlags.hotkeyRelevantFlags
        switch event.keyCode {
        case 54, 55:
            recordedCommand = flags.contains(.command)
        case 56, 60:
            recordedShift = flags.contains(.shift)
        case 58, 61:
            recordedOption = flags.contains(.option)
        case 59, 62:
            recordedControl = flags.contains(.control)
        case 63:
            recordedFunction = true
        default:
            if flags.contains(.function) { recordedFunction = true }
        }
    }

    private func scheduleModifierOnlySave() {
        let recordedCombo = currentRecordedModifierCombo()
        guard !recordedCombo.isEmpty else { return }

        pendingModifierSave?.cancel()
        let workItem = DispatchWorkItem {
            combo = recordedCombo
            stopRecording()
        }
        pendingModifierSave = workItem

        // Give the user a short moment to complete modifier-only combinations like Shift + fn.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    private func currentRecordedModifierCombo() -> HotkeyCombo {
        HotkeyCombo(
            function: recordedFunction,
            capsLock: false,
            shift: recordedShift,
            control: recordedControl,
            option: recordedOption,
            command: recordedCommand
        )
    }

    private func resetRecordedModifiers() {
        recordedFunction = false
        recordedCapsLock = false
        recordedShift = false
        recordedControl = false
        recordedOption = false
        recordedCommand = false
    }

    private func stopRecording() {
        pendingModifierSave?.cancel()
        pendingModifierSave = nil

        if let localKeyDownMonitor {
            NSEvent.removeMonitor(localKeyDownMonitor)
            self.localKeyDownMonitor = nil
        }
        if let localFlagsMonitor {
            NSEvent.removeMonitor(localFlagsMonitor)
            self.localFlagsMonitor = nil
        }
        isRecording = false
        resetRecordedModifiers()
    }
}

private struct SoftPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(configuration.isPressed ? 0.65 : 0.95))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.6)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Flow Layout (for term tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
