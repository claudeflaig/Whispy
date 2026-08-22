import AVFoundation
import Foundation
import Speech

@MainActor
protocol AppleSpeechSessionProtocol: AnyObject {
    var onTranscript: ((String) -> Void)? { get set }
    var onAudioLevel: ((Float) -> Void)? { get set }

    func beginCapture() throws
    func pauseCapture()
    func fallbackAudioSamples() async -> [Float]
    func start() async throws
    func stop() async throws -> String
    func cancel() async
}

enum AppleSpeechTranscriptionError: LocalizedError {
    case unavailable
    case unsupportedLocale(String)
    case noAudioFormat
    case modelInstallationFailed(String)
    case noText

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Speech ist auf diesem Mac nicht verfügbar. Erfordert macOS 26 oder neuer."
        case .unsupportedLocale(let locale):
            return "Apple Speech unterstützt die Sprache \(locale) auf diesem Mac nicht."
        case .noAudioFormat:
            return "Apple Speech konnte kein kompatibles Audioformat bereitstellen."
        case .modelInstallationFailed(let message):
            return "Das Apple-Sprachmodell konnte nicht installiert werden: \(message)"
        case .noText:
            return "Apple Speech hat keinen Text erkannt."
        }
    }
}

enum AppleSpeechSessionFactory {
    @MainActor private static var warmedSession: (any AppleSpeechSessionProtocol)?
    @MainActor private static var warmedKey: String?
    @MainActor private static var warmupTask: Task<Void, Never>?

    static var isAvailable: Bool {
        if #available(macOS 26.0, *) {
            return SpeechTranscriber.isAvailable
        }
        return false
    }

    @MainActor
    static func make(language: String, customTerms: [String]) throws -> any AppleSpeechSessionProtocol {
        guard #available(macOS 26.0, *) else {
            throw AppleSpeechTranscriptionError.unavailable
        }
        guard SpeechTranscriber.isAvailable else {
            throw AppleSpeechTranscriptionError.unavailable
        }

        let key = sessionKey(language: language, customTerms: customTerms)
        if warmedKey == key, let session = warmedSession {
            warmedSession = nil
            warmedKey = nil
            warmupTask = nil
            return session
        }

        warmupTask?.cancel()
        warmupTask = nil
        return AppleSpeechSession(language: language, customTerms: customTerms)
    }

    @MainActor
    static func prewarm(language: String, customTerms: [String]) {
        guard #available(macOS 26.0, *), SpeechTranscriber.isAvailable else { return }
        let key = sessionKey(language: language, customTerms: customTerms)
        guard warmedKey != key else { return }

        warmupTask?.cancel()
        warmedSession = nil
        warmedKey = nil
        warmupTask = Task { @MainActor in
            let session = AppleSpeechSession(language: language, customTerms: customTerms)
            do {
                try await session.start()
                try Task.checkCancellation()
                warmedSession = session
                warmedKey = key
            } catch {
                await session.cancel()
            }
            warmupTask = nil
        }
    }

    @MainActor
    private static func sessionKey(language: String, customTerms: [String]) -> String {
        let terms = customTerms.prefix(50).joined(separator: "\u{1F}")
        return "\(language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())\u{1E}\(terms)"
    }
}

@available(macOS 26.0, *)
@MainActor
private final class AppleSpeechSession: AppleSpeechSessionProtocol {
    var onTranscript: ((String) -> Void)?
    var onAudioLevel: ((Float) -> Void)?

    private let language: String
    private let customTerms: [String]
    private let capture = AppleSpeechAudioCapture()

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var resultsError: Error?
    private var finalizedText = ""
    private var latestText = ""
    private var isStarted = false

    init(language: String, customTerms: [String]) {
        self.language = language
        self.customTerms = Array(customTerms.prefix(50))
    }

    func beginCapture() throws {
        try capture.startBuffering { [weak self] level in
            Task { @MainActor in
                self?.onAudioLevel?(level)
            }
        }
    }

    func pauseCapture() {
        capture.pause()
        onAudioLevel?(0)
    }

    func fallbackAudioSamples() async -> [Float] {
        await capture.capturedFallbackSamples()
    }

    func start() async throws {
        guard !isStarted else { return }
        let requestedLocale = Self.locale(for: language)
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw AppleSpeechTranscriptionError.unsupportedLocale(requestedLocale.identifier)
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        try await Self.ensureAssetsInstalled(for: transcriber)

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw AppleSpeechTranscriptionError.noAudioFormat
        }

        // Startup can include a first-time model installation. Keep every captured chunk
        // until SpeechAnalyzer consumes it so the beginning of the utterance is never lost.
        let (inputStream, continuation) = AsyncStream<AnalyzerInput>.makeStream(
            bufferingPolicy: .unbounded
        )
        inputContinuation = continuation

        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: .init(priority: .userInitiated, modelRetention: .lingering)
        )
        self.analyzer = analyzer

        if !customTerms.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = customTerms
            try? await analyzer.setContext(context)
        }

        // Explicit preparation loads the acoustic model before microphone audio arrives.
        // A prewarmed session can therefore emit volatile results almost immediately.
        try await analyzer.prepareToAnalyze(in: format)
        try Task.checkCancellation()

        finalizedText = ""
        latestText = ""
        resultsError = nil

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    let snapshot = self.absorb(result)
                    self.latestText = snapshot
                    self.onTranscript?(snapshot)
                }
            } catch {
                self?.resultsError = error
            }
        }

        try await analyzer.start(inputSequence: inputStream)
        try Task.checkCancellation()

        await capture.connect(outputFormat: format) { buffer in
            continuation.yield(AnalyzerInput(buffer: buffer))
        }
        try Task.checkCancellation()
        isStarted = true
    }

    func stop() async throws -> String {
        guard isStarted else {
            if let resultsError { throw resultsError }
            throw AppleSpeechTranscriptionError.noText
        }

        capture.pause()
        onAudioLevel?(0)
        inputContinuation?.finish()
        inputContinuation = nil

        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            await analyzer?.cancelAndFinishNow()
            throw error
        }

        await resultsTask?.value
        resultsTask = nil
        analyzer = nil
        transcriber = nil
        isStarted = false

        if let resultsError {
            self.resultsError = nil
            throw resultsError
        }

        let text = (latestText.isEmpty ? finalizedText : latestText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AppleSpeechTranscriptionError.noText
        }
        return text
    }

    func cancel() async {
        capture.cancel()
        onAudioLevel?(0)
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        resultsTask = nil
        await analyzer?.cancelAndFinishNow()
        analyzer = nil
        transcriber = nil
        isStarted = false
        finalizedText = ""
        latestText = ""
    }

    private func absorb(_ result: SpeechTranscriber.Result) -> String {
        let text = String(result.text.characters)
        if result.isFinal {
            finalizedText += text
            return finalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (finalizedText + text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func locale(for language: String) -> Locale {
        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalized.lowercased() {
        case "de": return Locale(identifier: "de-DE")
        case "en": return Locale(identifier: "en-US")
        case "fr": return Locale(identifier: "fr-FR")
        case "it": return Locale(identifier: "it-IT")
        case "es": return Locale(identifier: "es-ES")
        default: return normalized.isEmpty ? Locale.current : Locale(identifier: normalized)
        }
    }

    private static func ensureAssetsInstalled(for transcriber: SpeechTranscriber) async throws {
        let installed = await SpeechTranscriber.installedLocales
        let hasEveryLocale = transcriber.selectedLocales.allSatisfy { selected in
            installed.contains { installedLocale in
                installedLocale.identifier(.bcp47) == selected.identifier(.bcp47)
            }
        }
        guard !hasEveryLocale else { return }

        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        } catch {
            throw AppleSpeechTranscriptionError.modelInstallationFailed(error.localizedDescription)
        }
    }
}

@available(macOS 26.0, *)
private final class AppleSpeechAudioCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "app.claudeflaig.whispy.apple-speech-audio", qos: .userInitiated)

    private var converter: AVAudioConverter?
    private var fallbackConverter: AVAudioConverter?
    private var nativeFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?
    private var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private var onLevel: (@Sendable (Float) -> Void)?
    private var pendingBuffers: [AVAudioPCMBuffer] = []
    private var fallbackSamples: [Float] = []
    private var isRunning = false

    func startBuffering(onLevel: @escaping @Sendable (Float) -> Void) throws {
        guard !isRunning else { return }
        self.onLevel = onLevel

        processingQueue.sync {
            converter = nil
            fallbackConverter = nil
            self.nativeFormat = nil
            pendingBuffers.removeAll(keepingCapacity: true)
            fallbackSamples.removeAll(keepingCapacity: true)
        }

        let input = engine.inputNode
        let nativeFormat = input.outputFormat(forBus: 0)
        self.nativeFormat = nativeFormat
        if let preparedOutputFormat = outputFormat, nativeFormat != preparedOutputFormat {
            converter = AVAudioConverter(from: nativeFormat, to: preparedOutputFormat)
        }
        if let fallbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) {
            fallbackConverter = nativeFormat == fallbackFormat
                ? nil
                : AVAudioConverter(from: nativeFormat, to: fallbackFormat)
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: nativeFormat) { [weak self] buffer, _ in
            guard let self, let ownedBuffer = Self.copy(buffer) else { return }
            self.onLevel?(Self.rms(of: buffer))
            self.processingQueue.async {
                self.process(ownedBuffer)
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func connect(
        outputFormat: AVAudioFormat,
        onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) async {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                self.outputFormat = outputFormat
                self.onBuffer = onBuffer

                if let nativeFormat = self.nativeFormat,
                   nativeFormat != outputFormat {
                    self.converter = AVAudioConverter(from: nativeFormat, to: outputFormat)
                } else {
                    self.converter = nil
                }

                let buffered = self.pendingBuffers
                self.pendingBuffers.removeAll(keepingCapacity: false)
                for buffer in buffered {
                    self.convertAndYield(buffer)
                }
                continuation.resume()
            }
        }
    }

    func pause() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        onLevel?(0)
    }

    func cancel() {
        pause()
        processingQueue.async {
            self.pendingBuffers.removeAll(keepingCapacity: false)
            self.fallbackSamples.removeAll(keepingCapacity: false)
            self.converter = nil
            self.fallbackConverter = nil
            self.nativeFormat = nil
            self.outputFormat = nil
            self.onBuffer = nil
        }
        onLevel = nil
    }

    func capturedFallbackSamples() async -> [Float] {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                continuation.resume(returning: self.fallbackSamples)
            }
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        appendFallbackSamples(from: buffer)

        guard outputFormat != nil, onBuffer != nil else {
            // First-use model installation can take time. Preserve the full utterance;
            // never discard its beginning merely to enforce an arbitrary memory cap.
            pendingBuffers.append(buffer)
            return
        }
        convertAndYield(buffer)
    }

    private func appendFallbackSamples(from buffer: AVAudioPCMBuffer) {
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else { return }

        let converted: AVAudioPCMBuffer
        if buffer.format == targetFormat {
            converted = buffer
        } else {
            guard let fallbackConverter else { return }
            let ratio = targetFormat.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
            guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
            var consumed = false
            var error: NSError?
            let status = fallbackConverter.convert(to: output, error: &error) { _, outStatus in
                guard !consumed else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                consumed = true
                outStatus.pointee = .haveData
                return buffer
            }
            guard error == nil, status != .error, output.frameLength > 0 else { return }
            converted = output
        }

        guard let channel = converted.floatChannelData?[0] else { return }
        fallbackSamples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(converted.frameLength)))
    }

    private func convertAndYield(_ buffer: AVAudioPCMBuffer) {
        guard let outputFormat, let onBuffer else { return }

        guard let converter else {
            onBuffer(buffer)
            return
        }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, outStatus in
            guard !consumed else {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard conversionError == nil, status != .error, converted.frameLength > 0 else { return }
        onBuffer(converted)
    }

    private static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard buffer.frameLength > 0,
              let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength)
        else { return nil }

        copy.frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)

        if let source = buffer.floatChannelData, let destination = copy.floatChannelData {
            for channel in 0..<channels {
                destination[channel].update(from: source[channel], count: frames)
            }
        } else if let source = buffer.int16ChannelData, let destination = copy.int16ChannelData {
            for channel in 0..<channels {
                destination[channel].update(from: source[channel], count: frames)
            }
        } else if let source = buffer.int32ChannelData, let destination = copy.int32ChannelData {
            for channel in 0..<channels {
                destination[channel].update(from: source[channel], count: frames)
            }
        } else {
            return nil
        }
        return copy
    }

    private static func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = (sum / Float(count)).squareRoot()
        let db = 20 * log10(max(rms, 1e-7))
        return max(0, min(1, (db + 50) / 50))
    }
}
