import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            switch appState.page {
            case .main, .settings:
                mainPage
            case .onboarding:
                onboardingPage
            case .workflow:
                workflowPage
            }
        }
        .frame(width: 360)
        .animation(.easeInOut(duration: 0.2), value: appState.page)
    }

    // MARK: - Main Page

    private var mainPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !appState.isConfigured {
                hintBanner(
                    icon: "key.fill",
                    text: "Einrichtung nötig: OpenAI-Key oder lokales Modell.",
                    action: "Einrichten"
                ) { appState.openSettings() }
            } else if !appState.accessibilityPermissionGranted {
                hintBanner(
                    icon: "hand.raised.fill",
                    text: "Zum Einfügen Bedienungshilfen erlauben.",
                    action: "Erlauben"
                ) { appState.requestAccessibilityPermission() }
            } else if BlitztextInstallLocationService.shouldOfferMoveToApplications {
                hintBanner(
                    icon: "externaldrive.badge.plus",
                    text: "Whispy nach /Applications verschieben.",
                    action: "Prüfen"
                ) { appState.openSettings() }
            }

            workflowList

            if !appState.dictationHistory.isEmpty {
                recentHistory
            }
        }
        .padding(14)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .glassCard(cornerRadius: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text("Whispy")
                    .font(.raycast(size: 15, weight: .bold))
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.raycast(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            GlassGroup(spacing: 6) {
                HStack(spacing: 6) {
                    Button {
                        appState.openSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .frame(width: 18, height: 18)
                    }
                    .help("Einstellungen")
                    .glassIconButtonStyle()

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                            .frame(width: 18, height: 18)
                    }
                    .help("Whispy beenden")
                    .glassIconButtonStyle()
                }
            }
        }
    }

    private var statusText: String {
        if !appState.isConfigured { return "Einrichtung nötig" }
        if appState.isDownloadingLocalModel {
            return appState.localModelDownloadStatusText ?? "Modell wird geladen …"
        }
        return "Bereit · \(appState.selectedLocalEngineDisplayName)"
    }

    private var statusColor: Color {
        if !appState.isConfigured { return .orange }
        if !appState.accessibilityPermissionGranted { return .orange }
        return .green
    }

    private var workflowList: some View {
        VStack(spacing: 2) {
            ForEach(WorkflowType.mainMenuCases) { type in
                WorkflowRowView(
                    type: type,
                    enabled: appState.isWorkflowAvailable(type),
                    customName: appState.displayName(for: type),
                    subtitle: appState.workflowSubtitle(for: type),
                    hotkeyLabel: appState.hotkeyLabel(for: type)
                ) {
                    appState.startWorkflow(type)
                }
            }
        }
        .padding(5)
        .glassCard(cornerRadius: 18)
    }

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Zuletzt")
                    .font(.raycast(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Alle anzeigen") {
                    appState.openSettings()
                }
                .font(.raycast(size: 11))
                .foregroundStyle(.secondary)
                .buttonStyle(SubtleButtonStyle())
            }
            .padding(.horizontal, 4)

            VStack(spacing: 2) {
                ForEach(appState.dictationHistory.prefix(3)) { entry in
                    MenuHistoryEntryRow(entry: entry) {
                        appState.copyToClipboard(entry.finalText)
                    } pasteAction: {
                        appState.pasteHistoryEntry(entry)
                    }
                }
            }
            .padding(5)
            .glassCard(cornerRadius: 16)
        }
    }

    private func hintBanner(icon: String, text: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text(text)
                .font(.raycast(size: 11.5, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action, action: perform)
                .controlSize(.small)
                .glassButtonStyle()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Onboarding

    private var onboardingPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 4) {
                Text("Sprechen statt tippen.")
                    .font(.raycast(size: 17, weight: .bold))
                Text("Kürzel halten, sprechen, loslassen – der Text landet im aktiven Textfeld.")
                    .font(.raycast(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                onboardingStep(number: "1", title: "Engine wählen", detail: "Apple Speech läuft sofort lokal. Optional OpenAI-Key oder WhisperKit-Modell.")
                onboardingStep(number: "2", title: "Rechte erlauben", detail: "Mikrofon und Bedienungshilfen für das Einfügen.")
                onboardingStep(number: "3", title: "Loslegen", detail: "fn halten für ein lokales Diktat.")
            }
            .padding(14)
            .glassCard(cornerRadius: 16)

            HStack {
                Button("Später") {
                    appState.page = .main
                }
                .glassButtonStyle()
                Spacer()
                Button("Jetzt einrichten") {
                    appState.openSettings()
                }
                .glassProminentButtonStyle()
            }
        }
        .padding(14)
    }

    private func onboardingStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.raycastMono(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.primary.opacity(0.07)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.raycast(size: 12, weight: .semibold))
                Text(detail)
                    .font(.raycast(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Workflow Page

    @ViewBuilder
    private var workflowPage: some View {
        if let workflow = appState.activeWorkflow {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        appState.resetCurrentWorkflow()
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 18, height: 18)
                    }
                    .help("Zurück")
                    .glassIconButtonStyle()

                    Label(appState.displayName(for: workflow.type), systemImage: workflow.type.icon)
                        .font(.raycast(size: 13, weight: .semibold))

                    Spacer()
                }

                WorkflowActiveView(workflow: workflow) {
                    workflow.reset()
                    workflow.start()
                } onCancel: {
                    appState.resetCurrentWorkflow()
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .glassCard(cornerRadius: 18)
            }
            .padding(14)
        }
    }
}

// MARK: - Active Workflow

/// One view for every workflow: recording, processing, done and error.
private struct WorkflowActiveView: View {
    let workflow: any Workflow
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        switch workflow.phase {
        case .idle, .running:
            if workflow.isRecording {
                recording
            } else {
                processing
            }
        case .done(let text):
            done(text)
        case .error(let message):
            failure(message)
        }
    }

    private var recording: some View {
        VStack(spacing: 14) {
            WaveformView(audioLevel: workflow.audioLevel, isRecording: true)
                .frame(height: 40)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            if workflow.supportsLiveTranscript, !workflow.liveTranscript.isEmpty {
                Text(workflow.liveTranscript)
                    .font(.raycast(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                Button("Verwerfen", role: .cancel, action: onCancel)
                    .glassButtonStyle()
                Button {
                    workflow.stop()
                } label: {
                    Label("Fertig", systemImage: "stop.fill")
                }
                .glassProminentButtonStyle()
            }

            Text("Esc verwirft die Aufnahme")
                .font(.raycast(size: 10.5))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
    }

    private var processing: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(runningMessage)
                .font(.raycast(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }

    private var runningMessage: String {
        if case .running(let message) = workflow.phase, !message.isEmpty {
            return message
        }
        return "Wird verarbeitet …"
    }

    private func done(_ text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.green)
                .padding(.top, 12)
            Text("Eingefügt")
                .font(.raycast(size: 14, weight: .semibold))
            Text(text)
                .font(.raycast(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.orange)
                .padding(.top, 12)
            Text(message)
                .font(.raycast(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
            Button("Nochmal versuchen", action: onRetry)
                .glassProminentButtonStyle()
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Menu History Row

private struct MenuHistoryEntryRow: View {
    let entry: DictationHistoryEntry
    let copyAction: () -> Void
    let pasteAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: pasteAction) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.finalText)
                        .font(.raycast(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text([entry.appName, entry.createdAt.formatted(.relative(presentation: .named))]
                        .compactMap { $0 }
                        .joined(separator: " · "))
                        .font(.raycast(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Erneut einfügen")

            Button(action: copyAction) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(SubtleButtonStyle())
            .foregroundStyle(.secondary)
            .opacity(isHovered ? 1 : 0)
            .help("Kopieren")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.07 : 0))
        )
        .onHover { isHovered = $0 }
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
