import Foundation
import AppKit
import Observation
import OSLog

private let transcriptionLogger = Logger(subsystem: "app.claudeflaig.whispy", category: "Transcription")

private func elapsedMilliseconds(since start: Date, until end: Date = Date()) -> Int {
    Int((end.timeIntervalSince(start) * 1000).rounded())
}

@Observable
@MainActor
final class TranscriptionWorkflow: Workflow {
    let type: WorkflowType
    var phase: WorkflowPhase = .idle {
        didSet { onPhaseChange?(phase) }
    }
    var onOutput: WorkflowOutputHandler?
    var onPhaseChange: WorkflowPhaseChangeHandler?
    private(set) var liveTranscript = ""
    var supportsLiveTranscript: Bool {
        (backend == .appleSpeech && !isUsingAppleFallback) || backend == .local
    }

    private let recorder = AudioRecorder()
    private let customTerms: [String]
    private let language: String
    private let backend: TranscriptionBackend
    private let localModelName: String
    private var transcriptionTask: Task<Void, Never>?
    private var maximumRecordingTask: Task<Void, Never>?

    private var appleSession: (any AppleSpeechSessionProtocol)?
    private var appleStartTask: Task<Void, Never>?
    private var appleIsRecording = false
    private var appleSessionReady = false
    private var appleStopRequested = false
    private var appleIsFinishing = false
    private var appleAudioLevel: Float = 0
    private var appleRecordingStartedAt: Date?
    private var isUsingAppleFallback = false

    private var whisperStreamingTask: Task<Void, Never>?
    private var whisperIsRecording = false
    private var whisperPreviewReady = false
    private var whisperIsFinishing = false
    private var whisperAudioLevel: Float = 0
    private var whisperRecordingStartedAt: Date?

    init(
        type: WorkflowType = .transcription,
        customTerms: [String] = [],
        language: String = "de",
        backend: TranscriptionBackend = .remote,
        localModelName: String = LocalTranscriptionService.recommendedFastModelName
    ) {
        self.type = type
        self.customTerms = customTerms
        self.language = language
        self.backend = backend
        self.localModelName = localModelName
    }

    func start() {
        liveTranscript = ""
        if backend == .appleSpeech {
            startAppleSpeech()
            return
        }
        if backend == .local {
            startWhisperKitStreaming()
            return
        }

        recorder.startRecording()
        if let error = recorder.errorMessage {
            phase = .error(error)
        } else {
            scheduleMaximumRecordingDuration()
            phase = .running("Aufnahme läuft ...")
        }
    }

    func stop() {
        maximumRecordingTask?.cancel()
        maximumRecordingTask = nil

        if backend == .appleSpeech {
            if isUsingAppleFallback {
                stopAppleFallbackRecording()
            } else {
                stopAppleSpeech()
            }
            return
        }
        if backend == .local {
            stopWhisperKitStreaming()
            return
        }

        if recorder.isRecording {
            recorder.stopRecording()
            guard !TranscriptionQualityService.shouldRejectRecording(duration: recorder.lastRecordingDuration) else {
                recorder.discardRecording()
                phase = .error("Keine Aufnahme erkannt.")
                return
            }
            transcribeRecordedFile()
        } else {
            transcriptionTask?.cancel()
            phase = .idle
        }
    }

    func reset() {
        transcriptionTask?.cancel()
        maximumRecordingTask?.cancel()
        maximumRecordingTask = nil
        appleStartTask?.cancel()
        appleStartTask = nil
        whisperStreamingTask?.cancel()
        whisperStreamingTask = nil

        if recorder.isRecording {
            recorder.stopRecording()
        }
        recorder.discardRecording()

        if let appleSession {
            Task { await appleSession.cancel() }
        }
        Task { await LocalTranscriptionService.shared.cancelStreaming() }
        self.appleSession = nil
        appleIsRecording = false
        appleSessionReady = false
        appleStopRequested = false
        appleIsFinishing = false
        appleAudioLevel = 0
        appleRecordingStartedAt = nil
        isUsingAppleFallback = false
        whisperIsRecording = false
        whisperPreviewReady = false
        whisperIsFinishing = false
        whisperAudioLevel = 0
        whisperRecordingStartedAt = nil
        liveTranscript = ""
        phase = .idle
    }

    var isRecording: Bool {
        if backend == .appleSpeech {
            return isUsingAppleFallback ? recorder.isRecording : appleIsRecording
        }
        if backend == .local {
            return whisperIsRecording
        }
        return recorder.isRecording
    }

    var audioLevel: Float {
        if backend == .appleSpeech {
            return isUsingAppleFallback ? recorder.audioLevel : appleAudioLevel
        }
        if backend == .local {
            return recorder.isRecording ? recorder.audioLevel : whisperAudioLevel
        }
        return recorder.audioLevel
    }

    // MARK: - WhisperKit streaming

    private func startWhisperKitStreaming() {
        whisperPreviewReady = false
        whisperIsFinishing = false
        liveTranscript = ""

        // Record the complete utterance immediately. The official WhisperKit stream drives
        // the live HUD once its model is ready; this recording remains the final source.
        recorder.startRecording()
        if let error = recorder.errorMessage {
            phase = .error(error)
            return
        }
        whisperIsRecording = true
        whisperRecordingStartedAt = Date()
        scheduleMaximumRecordingDuration()
        phase = .running("Aufnahme läuft · WhisperKit Live wird vorbereitet ...")

        whisperStreamingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await LocalTranscriptionService.shared.startStreaming(
                    language: language,
                    modelName: localModelName
                ) { [weak self] text, level in
                    Task { @MainActor in
                        self?.liveTranscript = text
                        self?.whisperAudioLevel = level
                    }
                }
                try Task.checkCancellation()
                whisperPreviewReady = true
                phase = .running("WhisperKit transkribiert live ...")
            } catch is CancellationError {
                await LocalTranscriptionService.shared.cancelStreaming()
                whisperPreviewReady = false
                whisperAudioLevel = 0
            } catch {
                await LocalTranscriptionService.shared.cancelStreaming()
                whisperPreviewReady = false
                whisperAudioLevel = 0
                // The complete backup recording stays active and can still be finalized.
                phase = .running("WhisperKit Live nicht verfügbar · Aufnahme läuft weiter ...")
            }
        }
    }

    private func stopWhisperKitStreaming() {
        guard whisperIsRecording, !whisperIsFinishing, recorder.isRecording else { return }

        recorder.stopRecording()
        whisperIsRecording = false
        whisperIsFinishing = true
        whisperAudioLevel = 0

        guard !TranscriptionQualityService.shouldRejectRecording(duration: recorder.lastRecordingDuration) else {
            whisperStreamingTask?.cancel()
            Task { await LocalTranscriptionService.shared.cancelStreaming() }
            recorder.discardRecording()
            whisperIsFinishing = false
            phase = .error("Keine Aufnahme erkannt.")
            return
        }

        phase = .running("WhisperKit-Transkript wird abgeschlossen ...")
        let previewWasReady = whisperPreviewReady
        whisperPreviewReady = false

        transcriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if previewWasReady {
                await LocalTranscriptionService.shared.stopStreamingPreview()
            } else {
                whisperStreamingTask?.cancel()
                await LocalTranscriptionService.shared.cancelStreaming()
            }
            guard !Task.isCancelled else { return }
            whisperStreamingTask = nil
            whisperIsFinishing = false
            transcribeRecordedFile(forceLocal: true)
        }
    }

    // MARK: - Apple Speech streaming

    private func startAppleSpeech() {
        guard AppleSpeechSessionFactory.isAvailable else {
            phase = .error(AppleSpeechTranscriptionError.unavailable.localizedDescription)
            return
        }

        appleStopRequested = false
        appleIsFinishing = false
        appleSessionReady = false

        do {
            let session = try AppleSpeechSessionFactory.make(
                language: language,
                customTerms: customTerms
            )
            session.onTranscript = { [weak self] text in
                self?.liveTranscript = text
            }
            session.onAudioLevel = { [weak self] level in
                self?.appleAudioLevel = level
            }
            try session.beginCapture()
            appleSession = session
            appleIsRecording = true
            appleRecordingStartedAt = Date()
            scheduleMaximumRecordingDuration()
            phase = .running("Aufnahme läuft · Apple Speech wird vorbereitet ...")
        } catch {
            appleIsRecording = false
            startWhisperKitFallback(after: error)
            return
        }

        appleStartTask = Task { @MainActor [weak self] in
            guard let self, let session = appleSession else { return }
            do {
                try await session.start()
                try Task.checkCancellation()
                appleStartTask = nil
                appleSessionReady = true
                phase = .running("Apple Speech hört live zu ...")

                if appleStopRequested {
                    finishAppleSpeech()
                }
            } catch is CancellationError {
                appleStartTask = nil
                await session.cancel()
                appleSession = nil
                appleIsRecording = false
                appleAudioLevel = 0
            } catch {
                appleStartTask = nil
                session.pauseCapture()
                let rescuedSamples = await session.fallbackAudioSamples()
                await session.cancel()
                appleSession = nil
                appleIsRecording = false
                appleAudioLevel = 0
                await recoverAppleAudio(
                    after: error,
                    samples: rescuedSamples,
                    duration: appleRecordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0,
                    stopTime: Date()
                )
            }
        }
    }

    private func stopAppleSpeech() {
        guard appleIsRecording || appleSession != nil || appleStartTask != nil else {
            phase = .idle
            return
        }

        appleStopRequested = true
        appleIsRecording = false
        appleAudioLevel = 0

        if appleSessionReady {
            finishAppleSpeech()
        } else {
            appleSession?.pauseCapture()
            phase = .running("Aufnahme gespeichert · Apple Speech wird vorbereitet ...")
        }
    }

    private func finishAppleSpeech() {
        guard !appleIsFinishing, let session = appleSession else { return }
        appleIsFinishing = true
        phase = .running("Live-Transkript wird abgeschlossen ...")

        let duration = appleRecordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        let stopTime = Date()

        transcriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let text = try await session.stop()
                try Task.checkCancellation()
                appleSession = nil
                appleSessionReady = false
                appleIsFinishing = false
                completeTranscription(text, recordingDuration: duration, stopTime: stopTime)
            } catch is CancellationError {
                appleSession = nil
                appleSessionReady = false
                appleIsFinishing = false
                return
            } catch {
                guard !Task.isCancelled else { return }
                let rescuedSamples = await session.fallbackAudioSamples()
                await session.cancel()
                appleSession = nil
                appleSessionReady = false
                appleIsFinishing = false
                transcriptionLogger.error(
                    "Apple transcription failed after \(elapsedMilliseconds(since: stopTime)) ms: \(error.localizedDescription, privacy: .private)"
                )
                await recoverAppleAudio(
                    after: error,
                    samples: rescuedSamples,
                    duration: duration,
                    stopTime: stopTime
                )
            }
        }
    }

    private func recoverAppleAudio(
        after appleError: Error,
        samples: [Float],
        duration: TimeInterval,
        stopTime: Date
    ) async {
        guard !samples.isEmpty,
              LocalTranscriptionService.isModelInstalled(localModelName) else {
            phase = .error(appleError.localizedDescription)
            return
        }

        isUsingAppleFallback = true
        liveTranscript = ""
        phase = .running("Apple Speech fehlgeschlagen · Aufnahme wird mit WhisperKit gerettet ...")
        do {
            let text = try await LocalTranscriptionService.shared.transcribe(
                audioSamples: samples,
                language: language,
                modelName: localModelName
            )
            try Task.checkCancellation()
            completeTranscription(text, recordingDuration: duration, stopTime: stopTime)
        } catch is CancellationError {
            return
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func startWhisperKitFallback(after appleError: Error) {
        guard !appleStopRequested,
              LocalTranscriptionService.isModelInstalled(localModelName) else {
            phase = .error(appleError.localizedDescription)
            return
        }

        recorder.startRecording()
        if let recorderError = recorder.errorMessage {
            phase = .error(recorderError)
            return
        }

        isUsingAppleFallback = true
        liveTranscript = ""
        phase = .running("Apple Speech nicht verfügbar · WhisperKit nimmt auf ...")
    }

    private func stopAppleFallbackRecording() {
        guard recorder.isRecording else {
            phase = .idle
            return
        }

        recorder.stopRecording()
        guard !TranscriptionQualityService.shouldRejectRecording(duration: recorder.lastRecordingDuration) else {
            recorder.discardRecording()
            phase = .error("Keine Aufnahme erkannt.")
            return
        }
        transcribeRecordedFile(forceLocal: true)
    }

    private func scheduleMaximumRecordingDuration() {
        maximumRecordingTask?.cancel()
        maximumRecordingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(120))
            guard let self, !Task.isCancelled, self.isRecording else { return }
            self.stop()
        }
    }

    // MARK: - Existing file-based backends

    private func transcribeRecordedFile(forceLocal: Bool = false) {
        guard let url = recorder.recordingURL else {
            phase = .error("Keine Aufnahme vorhanden.")
            return
        }

        phase = .running(backend == .local ? "Wird lokal transkribiert ..." : "Wird transkribiert ...")
        let recordingDuration = recorder.lastRecordingDuration
        let vocabularyHints = recordingDuration >= 0.9 ? customTerms : []
        let requestLanguage = language
        let stopTime = Date()

        transcriptionTask = Task(priority: .userInitiated) { @MainActor [weak self] in
            guard let self else { return }
            defer {
                try? FileManager.default.removeItem(at: url)
            }

            let requestStart = Date()
            do {
                let text: String
                switch forceLocal ? TranscriptionBackend.local : backend {
                case .remote:
                    text = try await TranscriptionService.transcribe(
                        audioURL: url,
                        customTerms: vocabularyHints,
                        language: requestLanguage
                    )
                case .local:
                    text = try await LocalTranscriptionService.shared.transcribe(
                        audioURL: url,
                        language: requestLanguage,
                        modelName: localModelName
                    )
                case .appleSpeech:
                    throw AppleSpeechTranscriptionError.unavailable
                }
                try Task.checkCancellation()

                transcriptionLogger.info(
                    "Transcription response in \(elapsedMilliseconds(since: requestStart)) ms"
                )
                completeTranscription(text, recordingDuration: recordingDuration, stopTime: stopTime)
            } catch {
                transcriptionLogger.error(
                    "Transcription failed after \(elapsedMilliseconds(since: stopTime)) ms: \(error.localizedDescription, privacy: .private)"
                )
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func completeTranscription(
        _ text: String,
        recordingDuration: TimeInterval,
        stopTime: Date
    ) {
        let cleaned = TranscriptionQualityService.cleanedTranscript(text)
        guard !TranscriptionQualityService.isLikelyArtifact(cleaned, recordingDuration: recordingDuration) else {
            transcriptionLogger.info(
                "Transcription rejected short artifact after \(elapsedMilliseconds(since: stopTime)) ms"
            )
            phase = .error("Keine Aufnahme erkannt.")
            return
        }

        transcriptionLogger.info(
            "Transcription ready in \(elapsedMilliseconds(since: stopTime)) ms"
        )
        liveTranscript = cleaned
        phase = .done(cleaned)
        onOutput?(cleaned)
    }
}
