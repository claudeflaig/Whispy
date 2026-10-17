import Foundation
import FluidAudio

/// NVIDIA Parakeet on the Neural Engine via FluidAudio, as in FoxSay.
///
/// Uses Parakeet Ultra, FluidAudio's post-trained Parakeet TDT 0.6B v3: same 25 European
/// languages, architecture and speed as v3, lower error rate in every measured language.
/// Transcribes a finished recording in a fraction of a second; there is no live preview.
actor ParakeetTranscriptionService {
    static let shared = ParakeetTranscriptionService()

    static let version: AsrModelVersion = .ultra
    static let displayName = "Parakeet v3 Ultra"
    static let downloadSizeLabel = "≈ 630 MB"
    static let modelPageURL = URL(string: "https://huggingface.co/FluidInference/parakeet-ultra-coreml")!

    /// Parakeet runs on the Apple Neural Engine; on Intel Macs it would fall back to the CPU.
    static var isSupported: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// FluidAudio keeps each model in a folder named after its repository next to this one.
    private static var modelDirectoryHint: URL {
        AppSupportPaths.localModelsDirectoryURL
            .appendingPathComponent("parakeet", isDirectory: true)
            .appendingPathComponent("parakeet-ultra", isDirectory: true)
    }

    static var isInstalled: Bool {
        AsrModels.modelsExist(at: modelDirectoryHint, version: version)
    }

    private var manager: AsrManager?

    func downloadAndInstall(progressHandler: @escaping @Sendable (Double) -> Void) async throws {
        try FileManager.default.createDirectory(
            at: Self.modelDirectoryHint.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        _ = try await AsrModels.download(to: Self.modelDirectoryHint, version: Self.version) { progress in
            let fraction = progress.fractionCompleted
            progressHandler(fraction.isFinite ? fraction : 0)
        }
        progressHandler(1)
    }

    /// Loads and compiles the model so the first dictation doesn't wait for it.
    func prepare() async throws {
        _ = try await loadedManager()
    }

    func transcribe(audioURL: URL, language: String) async throws -> String {
        let manager = try await loadedManager()
        var decoderState = try TdtDecoderState(decoderLayers: Self.version.decoderLayers)
        let result = try await manager.transcribe(
            audioURL,
            decoderState: &decoderState,
            language: Language(rawValue: language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        )
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw LocalTranscriptionError.noText }
        return text
    }

    private func loadedManager() async throws -> AsrManager {
        if let manager { return manager }
        guard Self.isInstalled else {
            throw LocalTranscriptionError.modelMissing(Self.modelDirectoryHint)
        }
        let models = try await AsrModels.downloadAndLoad(to: Self.modelDirectoryHint, version: Self.version)
        let manager = AsrManager()
        try await manager.loadModels(models)
        self.manager = manager
        return manager
    }
}
