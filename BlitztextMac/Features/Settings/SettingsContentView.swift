import SwiftUI
import AppKit

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general
    case behavior
    case hotkeys
    case workflows
    case context
    case history
    case access

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "Transkription"
        case .behavior: return "Verhalten"
        case .hotkeys: return "Tastenkürzel"
        case .workflows: return "Workflows"
        case .context: return "App-Kontext"
        case .history: return "Verlauf"
        case .access: return "Zugang & System"
        }
    }

    var icon: String {
        switch self {
        case .general: return "waveform"
        case .behavior: return "slider.horizontal.3"
        case .hotkeys: return "keyboard"
        case .workflows: return "sparkles"
        case .context: return "app.connected.to.app.below.fill"
        case .history: return "clock.arrow.circlepath"
        case .access: return "lock.shield"
        }
    }
}

struct SettingsContentView: View {
    @Bindable var appState: AppState
    @State private var selection: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
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
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
        } detail: {
            let pane = selection ?? .general
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(pane.title)
                        .font(.raycast(size: 22, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    if pane == .access {
                        AccessSettingsView(appState: appState)
                    } else {
                        CustomizeSettingsView(appState: appState, pane: pane)
                    }
                }
                .frame(maxWidth: 680, alignment: .topLeading)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .navigationTitle(pane.title)
        }
        .frame(minWidth: 780, minHeight: 560)
        .tint(.raycastRed)
        .onAppear {
            appState.refreshAccessibilityPermission()
            if !appState.accessibilityPermissionGranted || !appState.isConfigured {
                selection = .access
            }
        }
    }
}

// MARK: - Section Label (quiet style)

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.raycast(size: 10.5, weight: .semibold))
            .tracking(0.45)
            .foregroundStyle(.secondary)
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
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.7)
                        )
                    Image(systemName: systemImage)
                        .font(.raycast(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.raycast(size: 15, weight: .bold))
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

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18)
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
        VStack(alignment: .leading, spacing: 20) {
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
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
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
        .padding(16)
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
        VStack(alignment: .leading, spacing: 18) {

            if pane == .general {
// MARK: Lokaler Modus
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Sicherer Lokaler Modus")

                Toggle("Sicherer Lokaler Modus", isOn: $appState.appSettings.secureLocalModeEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: appState.appSettings.secureLocalModeEnabled) { _, newValue in
                        if newValue,
                           appState.effectiveLocalTranscriptionEngine == .whisperKit,
                           !appState.selectedLocalModelIsInstalled {
                            appState.installSelectedLocalModel()
                        }
                    }

                HStack(spacing: 8) {
                    Text("Transkriptions-Engine")
                        .font(.raycast(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $appState.appSettings.selectedLocalTranscriptionEngine) {
                        ForEach(appState.availableLocalTranscriptionEngines) { engine in
                            Text("\(engine.displayName) · \(engine.detail)").tag(engine)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
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
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: appState.selectedLocalModelIsInstalled ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.raycast(size: 11, weight: .semibold))
                            .foregroundStyle(appState.selectedLocalModelIsInstalled ? .green : .blue)
                        Text(appState.selectedLocalModelIsInstalled ? "\(installedLocalModels.count) lokales WhisperKit-Modell installiert." : "Das ausgewählte Modell wird beim Installieren lokal gespeichert.")
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
                                Text("\(model.displayName) · \(model.installStateLabel)").tag(model.id)
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
            }

            if pane == .context {
// MARK: App-Kontext
            SettingsCard(
                title: "App-Kontext",
                subtitle: "Whispy erkennt die Ziel-App und nutzt Kategorie und Stil als Kontext. Wähle Apps aus einer Liste — keine Bundle-IDs nötig.",
                systemImage: "app.connected.to.app.below.fill",
                accent: .green
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(AppContextRule.Category.allCases) { category in
                        AppContextRuleRow(rule: appContextRuleBinding(for: category), availableApps: availableAppOptions)
                    }
                }
            }
            }

            if pane == .history {
// MARK: Verlauf
            SettingsCard(
                title: "Verlauf",
                subtitle: "Die letzten \(AppState.historyLimit) Diktate bleiben lokal auf diesem Mac. Kopieren oder erneut einfügen.",
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
                title: "Tastenkürzel",
                subtitle: "Klicke auf ein Kürzel und drücke anschließend deine gewünschte Tastenkombination.",
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
                    .buttonStyle(SoftPillButtonStyle())
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

            // MARK: Eigennamen
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Eigennamen")

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
            }

            if pane == .behavior {
                behaviorSection
            }
        }
        .padding(16)
        .onAppear {
            availableAppOptions = AppContextAppOption.availableOptions()
        }
    }

    private func workflowAccentColor(_ type: WorkflowType) -> Color { .secondary }

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
                ?? AppContextAppOption(name: identifier, bundleIdentifier: identifier)
        }
    }

    private var remainingApps: [AppContextAppOption] {
        availableApps.filter { !rule.bundleIdentifiers.contains($0.bundleIdentifier) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                    Image(systemName: rule.category.icon)
                        .font(.raycast(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.category.displayName)
                        .font(.raycast(size: 12.8, weight: .bold))
                    Text("Wähle Apps aus der Liste und lege den Schreibstil fest.")
                        .font(.raycast(size: 10.2, weight: .medium))
                        .foregroundStyle(.secondary)
                }

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
                            Image(systemName: "app.fill")
                                .font(.raycast(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.055))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.085), lineWidth: 0.6)
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
                    Button("Leeren") {
                        rule.bundleIdentifiers.removeAll()
                    }
                    .font(.raycast(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .glassButtonStyle()
                }

                Spacer()

                Text("\(rule.bundleIdentifiers.count) Apps")
                    .font(.raycast(size: 9.5, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.032))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
        )
    }
}

private struct HistoryEntryRow: View {
    let entry: DictationHistoryEntry
    let copyAction: () -> Void
    let pasteAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                Image(systemName: entry.workflowType.icon)
                    .font(.raycast(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 32, height: 32)

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

            VStack(spacing: 5) {
                Button("Kopieren", action: copyAction)
                    .glassButtonStyle()
                    .font(.raycast(size: 10, weight: .medium))
                Button("Einfügen", action: pasteAction)
                    .glassButtonStyle()
                    .font(.raycast(size: 10, weight: .medium))
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.6)
        )
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                    Image(systemName: icon)
                        .font(.raycast(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.raycast(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.raycast(size: 10.8))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Text("Auslösen mit")
                    .font(.raycast(size: 10.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 12)
                HotkeyComboPicker(combo: $combo, title: hotkeyLabel)
            }
            .padding(.leading, 43)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 0.6)
        )
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
                    Image(systemName: isRecording ? "record.circle.fill" : "keyboard.badge.ellipsis")
                        .font(.raycast(size: 10.5, weight: .semibold))
                        .foregroundStyle(isRecording ? .red : .secondary)
                    Text(isRecording ? "Kombination drücken …" : title)
                        .font(.raycastMono(size: 11, weight: .medium))
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minWidth: 168, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isRecording ? Color.red.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.92))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 0.8)
                )
            }
            .glassButtonStyle()
            .fixedSize(horizontal: true, vertical: false)

            Button {
                combo = HotkeyCombo()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.raycast(size: 13))
                    .foregroundStyle(combo.isEmpty ? .quaternary : .tertiary)
            }
            .glassButtonStyle()
            .help("Kürzel löschen")
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var labelColor: Color {
        if isRecording { return .red }
        return combo.isEmpty ? .orange : .secondary
    }

    private var borderColor: Color {
        if isRecording { return .red.opacity(0.45) }
        return combo.isEmpty ? .orange.opacity(0.5) : .primary.opacity(0.05)
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
