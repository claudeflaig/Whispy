import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            switch appState.page {
            case .main:
                mainPage
            case .onboarding:
                onboardingPage
            case .settings:
                settingsPage
            case .workflow:
                workflowPage
            }
        }
        .frame(width: 420)
        .tint(.raycastRed)
        .animation(.easeInOut(duration: 0.2), value: appState.page)
    }

    // MARK: - Main Page

    private var mainPage: some View {
        VStack(spacing: 0) {
            premiumHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if BlitztextInstallLocationService.shouldOfferMoveToApplications {
                        installHintBanner
                    }

                    transcriptionModePanel

                    if !appState.accessibilityPermissionGranted {
                        accessibilityHintBanner
                    }

                    workflowsPanel

                    historyPanel
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .frame(maxHeight: 640)

            appFooter
        }
        .background(menuBackground)
    }

    private var workflowsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Workflows")
                    .font(.raycast(size: 10.5, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Sprechen statt tippen")
                    .font(.raycast(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)

            ForEach(WorkflowType.mainMenuCases) { type in
                let enabled = appState.isWorkflowAvailable(type)
                WorkflowRowView(
                    type: type,
                    enabled: enabled,
                    customName: appState.displayName(for: type),
                    subtitle: appState.workflowSubtitle(for: type),
                    hotkeyLabel: appState.hotkeyLabel(for: type)
                ) {
                    appState.startWorkflow(type)
                }
            }
        }
    }

    private var menuBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Color.primary.opacity(0.018)
        }
    }

    private var premiumHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.raycastRed.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.raycastRed.opacity(0.26), lineWidth: 0.7)
                        )
                    Image(systemName: "waveform.badge.microphone")
                        .font(.raycast(size: 17, weight: .semibold))
                        .foregroundStyle(Color.raycastRed)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Whispy")
                            .font(.raycast(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("Preview")
                            .font(.raycast(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.06)))
                    }
                    Text("Lokale und OpenAI-Diktate in jedem Textfeld.")
                        .font(.raycast(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 7) {
                    Button {
                        appState.openSettings()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.raycast(size: 14, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.72))
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
                                )

                            if !appState.accessibilityPermissionGranted {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 7, height: 7)
                                    .offset(x: -3, y: 3)
                            }
                        }
                    }
                    .help("Einstellungen")
                    .buttonStyle(SubtleButtonStyle())

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Beenden", systemImage: "power")
                            .font(.raycast(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.primary.opacity(0.045))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.7)
                            )
                    }
                    .help("Whispy beenden")
                    .buttonStyle(SubtleButtonStyle())
                }
            }

            if appState.isConfigured {
                configuredHeader
            } else {
                unconfiguredHeader
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Rectangle().fill(.ultraThinMaterial))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.7)
        }
    }

    private var transcriptionModePanel: some View {
        let modelOptions = LocalTranscriptionService.modelOptions()
        let selectedModelInstalled = appState.selectedLocalModelIsInstalled

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.065))
                    Image(systemName: "arrow.triangle.branch")
                        .font(.raycast(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Transkription")
                            .font(.raycast(size: 12.5, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("LOKAL + OPENAI")
                            .font(.raycast(size: 8.5, weight: .bold))
                            .tracking(0.35)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.055))
                            )
                    }

                    Text("Du kannst lokale und serverbasierte Kürzel parallel verwenden.")
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                modeFactRow(label: "Lokal", value: appState.selectedLocalEngineDisplayName, color: .primary)
                modeFactRow(label: "OpenAI", value: "Whisper API", color: .primary)
                modeFactRow(label: "Kürzel", value: "Pro Workflow getrennt", color: .secondary)
            }

            HStack(spacing: 8) {
                Text("Lokale Engine")
                    .font(.raycast(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("", selection: $appState.appSettings.selectedLocalTranscriptionEngine) {
                    ForEach(appState.availableLocalTranscriptionEngines) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .controlSize(.small)
            }

            if appState.effectiveLocalTranscriptionEngine == .appleSpeech {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "apple.intelligence")
                        .font(.raycast(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Echtzeit-Text mit Apples SpeechTranscriber. Das Sprachmodell wird beim ersten Einsatz von macOS installiert.")
                        .font(.raycast(size: 10.2, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(spacing: 8) {
                    Text("Whisper-Modell")
                        .font(.raycast(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    Picker("", selection: Binding(
                        get: { appState.selectedLocalModelName },
                        set: { appState.appSettings.selectedLocalTranscriptionModelName = $0 }
                    )) {
                        ForEach(modelOptions) { model in
                            Text(model.shortDisplayName).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .controlSize(.small)
                    .disabled(appState.isDownloadingLocalModel)
                }
            }

            if appState.effectiveLocalTranscriptionEngine == .whisperKit,
               let progress = appState.localModelDownloadProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                    Text(appState.localModelDownloadStatusText ?? "Modell wird geladen...")
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            } else if appState.effectiveLocalTranscriptionEngine == .whisperKit && !selectedModelInstalled {
                Button(appState.localModelDownloadButtonTitle) {
                    appState.installSelectedLocalModel()
                }
                .controlSize(.small)
            }

            if let errorText = appState.localModelDownloadErrorText {
                Text(errorText)
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.7)
        )
    }

    private func modeFactRow(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.raycast(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.raycast(size: 10.5, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func modePanelSubtitle(selectedModelInstalled: Bool) -> String {
        if appState.appSettings.secureLocalModeEnabled {
            if appState.isDownloadingLocalModel {
                return appState.localModelDownloadStatusText ?? "Lokales Modell wird geladen."
            }
            if selectedModelInstalled {
                return "Lokal mit \(appState.selectedLocalModelDisplayName)."
            }
            return "\(appState.selectedLocalModelDisplayName) ist noch nicht installiert."
        }

        return "Whispy nutzt gerade die OpenAI-Transkription."
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Verlauf", systemImage: "clock.arrow.circlepath")
                    .font(.raycast(size: 11.5, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("letzte 20")
                    .font(.raycast(size: 9, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.055)))
            }

            if appState.dictationHistory.isEmpty {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "sparkles")
                        .font(.raycast(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Deine letzten Diktate erscheinen hier direkt im Menübar-Popup — lokal gespeichert und sofort wiederverwendbar.")
                        .font(.raycast(size: 10.8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: 7) {
                        ForEach(appState.dictationHistory.prefix(20)) { entry in
                            MenuHistoryEntryRow(entry: entry) {
                                appState.copyToClipboard(entry.finalText)
                            } pasteAction: {
                                appState.pasteHistoryEntry(entry)
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: 220)

                HStack(spacing: 8) {
                    Text("Nur lokal auf diesem Mac")
                        .font(.raycast(size: 9.8, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Löschen") {
                        appState.clearDictationHistory()
                    }
                    .font(.raycast(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .buttonStyle(SubtleButtonStyle())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.045), radius: 14, y: 7)
    }

    private var accessibilityHintBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.raycast(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text("Einfügen braucht Bedienungshilfen.")
                    .font(.raycast(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Nach Updates kann macOS die Freigabe neu verlangen.")
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button("Öffnen") {
                appState.requestAccessibilityPermission()
            }
            .font(.raycast(size: 10.5, weight: .medium))
            .buttonStyle(SubtleButtonStyle())
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var configuredHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.055))
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Bereit für Diktat")
                    .font(.raycast(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                Text("fn lokal · fn + Shift OpenAI")
                    .font(.raycast(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("LIVE")
                .font(.raycast(size: 9, weight: .black))
                .tracking(0.7)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.055)))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.06), radius: 14, y: 8)
    }

    private var installHintBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.raycast(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text("Für sauberen Anmeldestart nach /Applications verschieben.")
                    .font(.raycast(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Sonst entstehen leichter doppelte Login-Items oder uneinheitliche Updates.")
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button("Prüfen") {
                appState.openSettings()
            }
            .font(.raycast(size: 10.5, weight: .medium))
            .buttonStyle(SubtleButtonStyle())
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var onboardingPage: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Willkommen bei Whispy")
                    .font(.raycast(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button("Später") {
                    appState.page = .main
                }
                .font(.raycast(size: 11, weight: .medium))
                .buttonStyle(SubtleButtonStyle())
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.5)
            )

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.055))
                            .frame(width: 42, height: 42)
                        Image(systemName: "sparkles")
                            .font(.raycast(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Einmal einrichten, dann direkt loslegen.")
                            .font(.raycast(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Eigenen OpenAI API Key eintragen. Danach sprechen und einfügen.")
                            .font(.raycast(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    if BlitztextInstallLocationService.shouldOfferMoveToApplications {
                        onboardingInstallCard
                    }

                    onboardingStep(number: "1", title: "OpenAI Key speichern", detail: "Öffne die Einstellungen und trage deinen eigenen OpenAI API Key ein.")
                    onboardingStep(number: "2", title: "Berechtigungen erlauben", detail: "Mikrofon und Bedienungshilfen für das Einfügen freigeben.")
                    onboardingStep(number: "3", title: "Workflow wählen", detail: "Whispy oder einen der Verbesserer-Workflows direkt aus der Menüleiste starten.")
                }

                HStack(spacing: 8) {
                    Button {
                        appState.openSettings()
                    } label: {
                        Text("Jetzt einrichten")
                            .font(.raycast(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(SubtleButtonStyle())

                    Text("Du findest alles später im Zahnrad.")
                        .font(.raycast(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Spacer(minLength: 0)

            appFooter
        }
    }

    private var unconfiguredHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "key.fill")
                    .font(.raycast(size: 16, weight: .medium))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 4) {
                Text("Einrichtung n\u{00F6}tig")
                    .font(.raycast(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\u{00D6}ffne die Einstellungen und hinterlege deine Zugangsdaten, um loszulegen.")
                    .font(.raycast(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }

            Button {
                appState.openSettings()
            } label: {
                Text("Einstellungen \u{00F6}ffnen")
                    .font(.raycast(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            }
            .buttonStyle(SubtleButtonStyle())
        }
    }

    private func onboardingStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.raycast(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.raycast(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.raycast(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var onboardingInstallCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.down.app")
                .font(.raycast(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text("Lege Whispy zuerst nach /Applications.")
                    .font(.raycast(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Das hält Anmeldestart, spätere Updates und das Entfernen sauber auf einer einzigen App-Kopie.")
                    .font(.raycast(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Settings Page

    private var settingsPage: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 12) {
                Button {
                    appState.page = .main
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.raycast(size: 10, weight: .semibold))
                        Text("Zur\u{00FC}ck")
                            .font(.raycast(size: 12))
                            .fixedSize()
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(SubtleButtonStyle())
                .frame(width: 120, alignment: .leading)

                Text("Einstellungen")
                    .font(.raycast(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .center)

                settingsQuickAction
                    .frame(width: 190, alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()

            SettingsContentView(appState: appState)

            Spacer(minLength: 0)

            appFooter
        }
    }

    private var settingsQuickAction: some View {
        HStack(spacing: 10) {
            if !appState.accessibilityPermissionGranted {
                Button {
                    appState.requestAccessibilityPermission()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised")
                            .font(.raycast(size: 10, weight: .semibold))
                        Text("Rechte")
                            .font(.raycast(size: 12))
                            .fixedSize()
                    }
                    .foregroundStyle(.orange)
                }
                .buttonStyle(SubtleButtonStyle())
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.raycast(size: 10, weight: .semibold))
                    Text("Beenden")
                        .font(.raycast(size: 12))
                        .fixedSize()
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(SubtleButtonStyle())
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Workflow Page

    private var workflowPage: some View {
        VStack(spacing: 0) {
            if let workflow = appState.activeWorkflow {
                // Header bar
                HStack {
                    Button {
                        appState.resetCurrentWorkflow()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.raycast(size: 10, weight: .semibold))
                            Text("Zur\u{00FC}ck")
                                .font(.raycast(size: 12))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(SubtleButtonStyle())

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: workflow.type.icon)
                            .font(.raycast(size: 11))
                            .foregroundStyle(workflowIconColor(workflow.type))
                        Text(appState.displayName(for: workflow.type))
                            .font(.raycast(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // Content
                switch workflow.type {
                case .transcription, .localTranscription:
                    if let w = workflow as? TranscriptionWorkflow {
                        TranscriptionActiveView(workflow: w)
                    }
                case .textImprover:
                    if let w = workflow as? TextImprovementWorkflow {
                        TextImproverActiveView(workflow: w)
                    }
                case .dampfAblassen:
                    if let w = workflow as? DampfAblassenWorkflow {
                        DampfAblassenActiveView(workflow: w)
                    }
                case .emojiText:
                    if let w = workflow as? EmojiTextWorkflow {
                        EmojiTextActiveView(workflow: w)
                    }
                }

                Spacer(minLength: 0)

                appFooter
            }
        }
    }

    private var appFooter: some View {
        HStack {
            Spacer()
            Button("Beenden") {
                NSApplication.shared.terminate(nil)
            }
            .font(.raycast(size: 10, weight: .medium))
            .foregroundStyle(.quaternary)
            .buttonStyle(SubtleButtonStyle())
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func workflowIconColor(_ type: WorkflowType) -> Color { .secondary }
}

// MARK: - Menu History Row

private struct MenuHistoryEntryRow: View {
    let entry: DictationHistoryEntry
    let copyAction: () -> Void
    let pasteAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                Image(systemName: entry.workflowType.icon)
                    .font(.raycast(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(entry.workflowName)
                        .font(.raycast(size: 10.5, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(entry.contextCategory.displayName)
                        .font(.raycast(size: 8, weight: .black))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.055)))

                    if let appName = entry.appName {
                        Text(appName)
                            .font(.raycast(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Text(entry.finalText)
                    .font(.raycast(size: 10.4, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Button(action: copyAction) {
                    Image(systemName: "doc.on.doc")
                        .font(.raycast(size: 10.5, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .help("Kopieren")
                .buttonStyle(SubtleButtonStyle())

                Button(action: pasteAction) {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.raycast(size: 10.5, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .help("Einfügen")
                .buttonStyle(SubtleButtonStyle())
            }
            .foregroundStyle(.secondary)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
        )
    }

}

// MARK: - Subtle Button Style

struct SubtleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Transcription Active View

struct TranscriptionActiveView: View {
    @Bindable var workflow: TranscriptionWorkflow

    var body: some View {
        VStack(spacing: 0) {
            switch workflow.phase {
            case .idle, .running:
                if workflow.isRecording {
                    recordingView(onStop: { workflow.stop() })
                } else {
                    processingView(message: "Wird transkribiert \u{2026}")
                }

            case .done(let text):
                autoPasteView(text: text)

            case .error(let msg):
                errorView(message: msg) {
                    workflow.reset()
                    workflow.start()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func recordingView(onStop: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            WaveformView(audioLevel: workflow.audioLevel, isRecording: true)
                .frame(height: 44)
                .padding(.horizontal, 24)

            // Monochrome stop button
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.primary.opacity(0.7))
                        .frame(width: 14, height: 14)
                }
            }
            .buttonStyle(.plain)

            Text("Ich h\u{00F6}re zu \u{2026} Klicke zum Stoppen.")
                .font(.raycast(size: 11))
                .foregroundStyle(.tertiary)

            Spacer().frame(height: 8)
        }
    }
}

// MARK: - Text Improver Active View

struct TextImproverActiveView: View {
    @Bindable var workflow: TextImprovementWorkflow

    var body: some View {
        VStack(spacing: 0) {
            switch workflow.phase {
            case .idle, .running:
                if workflow.isRecording {
                    recordingView(onStop: { workflow.stop() })
                } else {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 24)
                        ProgressView()
                            .scaleEffect(0.7)
                            .controlSize(.small)
                        if case .running(let msg) = workflow.phase {
                            Text(msg)
                                .font(.raycast(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer().frame(height: 24)
                    }
                }

            case .done(let text):
                autoPasteView(text: text)

            case .error(let msg):
                errorView(message: msg) {
                    workflow.reset()
                    workflow.start()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func recordingView(onStop: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            WaveformView(audioLevel: workflow.audioLevel, isRecording: true)
                .frame(height: 44)
                .padding(.horizontal, 24)

            // Monochrome stop button
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.primary.opacity(0.7))
                        .frame(width: 14, height: 14)
                }
            }
            .buttonStyle(.plain)

            Text("Ich h\u{00F6}re zu \u{2026} Klicke zum Stoppen.")
                .font(.raycast(size: 11))
                .foregroundStyle(.tertiary)

            Spacer().frame(height: 8)
        }
    }
}

// MARK: - Rage Mode Active View

struct DampfAblassenActiveView: View {
    @Bindable var workflow: DampfAblassenWorkflow

    var body: some View {
        VStack(spacing: 0) {
            switch workflow.phase {
            case .idle, .running:
                if workflow.isRecording {
                    recordingView(onStop: { workflow.stop() })
                } else {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 24)
                        ProgressView()
                            .scaleEffect(0.7)
                            .controlSize(.small)
                        if case .running(let msg) = workflow.phase {
                            Text(msg)
                                .font(.raycast(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer().frame(height: 24)
                    }
                }

            case .done(let text):
                autoPasteView(text: text)

            case .error(let msg):
                errorView(message: msg) {
                    workflow.reset()
                    workflow.start()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func recordingView(onStop: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            WaveformView(audioLevel: workflow.audioLevel, isRecording: true)
                .frame(height: 44)
                .padding(.horizontal, 24)

            // Monochrome stop button
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.primary.opacity(0.7))
                        .frame(width: 14, height: 14)
                }
            }
            .buttonStyle(.plain)

            Text("Ich h\u{00F6}re zu \u{2026} Klicke zum Stoppen.")
                .font(.raycast(size: 11))
                .foregroundStyle(.tertiary)

            Spacer().frame(height: 8)
        }
    }
}

// MARK: - Emoji Text Active View

struct EmojiTextActiveView: View {
    @Bindable var workflow: EmojiTextWorkflow

    var body: some View {
        VStack(spacing: 0) {
            switch workflow.phase {
            case .idle, .running:
                if workflow.isRecording {
                    recordingView(onStop: { workflow.stop() })
                } else {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 24)
                        ProgressView()
                            .scaleEffect(0.7)
                            .controlSize(.small)
                        if case .running(let msg) = workflow.phase {
                            Text(msg)
                                .font(.raycast(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer().frame(height: 24)
                    }
                }

            case .done(let text):
                autoPasteView(text: text)

            case .error(let msg):
                errorView(message: msg) {
                    workflow.reset()
                    workflow.start()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func recordingView(onStop: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            WaveformView(audioLevel: workflow.audioLevel, isRecording: true)
                .frame(height: 44)
                .padding(.horizontal, 24)

            // Monochrome stop button
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .strokeBorder(.primary.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.primary.opacity(0.7))
                        .frame(width: 14, height: 14)
                }
            }
            .buttonStyle(.plain)

            Text("Ich h\u{00F6}re zu \u{2026} Klicke zum Stoppen.")
                .font(.raycast(size: 11))
                .foregroundStyle(.tertiary)

            Spacer().frame(height: 8)
        }
    }
}

// MARK: - Shared Result / Error Views

private func processingView(message: String) -> some View {
    VStack(spacing: 12) {
        Spacer().frame(height: 24)
        ProgressView()
            .scaleEffect(0.7)
            .controlSize(.small)
        Text(message)
            .font(.raycast(size: 11.5))
            .foregroundStyle(.secondary)
        Spacer().frame(height: 24)
    }
}

private func autoPasteView(text: String) -> some View {
    VStack(spacing: 12) {
        Spacer().frame(height: 20)

        ZStack {
            Circle()
                .fill(Color.green.opacity(0.1))
                .frame(width: 44, height: 44)
            Image(systemName: "checkmark.circle.fill")
                .font(.raycast(size: 24))
                .foregroundStyle(.green)
        }

        Text("Eingef\u{00FC}gt")
            .font(.raycast(size: 14, weight: .semibold))
            .foregroundStyle(.primary)

        Text(text)
            .font(.raycast(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)

        Spacer().frame(height: 12)
    }
}

private func errorView(message: String, onRetry: @escaping () -> Void) -> some View {
    VStack(spacing: 10) {
        Spacer().frame(height: 16)

        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 40, height: 40)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.raycast(size: 18))
                .foregroundStyle(.orange)
        }

        Text(message)
            .font(.raycast(size: 11.5))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)

        Button(action: onRetry) {
            Text("Nochmal versuchen")
                .font(.raycast(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(SubtleButtonStyle())

        Spacer().frame(height: 4)
    }
}
