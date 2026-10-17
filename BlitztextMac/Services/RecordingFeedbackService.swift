import AppKit
import CoreAudio

/// Audible start/stop cues and optional muting of the system output while the
/// microphone is open, so music or a video does not end up in the dictation.
@MainActor
final class RecordingFeedbackService {
    enum Cue {
        case start
        case stop
        case cancel

        var soundName: NSSound.Name {
            switch self {
            case .start: return "Tink"
            case .stop: return "Pop"
            case .cancel: return "Funk"
            }
        }
    }

    private(set) var isActive = false
    private var mutedOutputDevice: AudioDeviceID?
    private var muteTask: Task<Void, Never>?

    func recordingStarted(playSound: Bool, muteSystemAudio: Bool) {
        guard !isActive else { return }
        isActive = true
        if playSound {
            play(.start)
        }
        guard muteSystemAudio else { return }

        // Let the start cue finish before the output goes silent.
        muteTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(playSound ? 220 : 0))
            guard let self, !Task.isCancelled, self.isActive else { return }
            self.muteDefaultOutput()
        }
    }

    func recordingEnded(_ cue: Cue, playSound: Bool) {
        guard isActive else { return }
        isActive = false
        muteTask?.cancel()
        muteTask = nil
        restoreOutput()
        if playSound {
            play(cue)
        }
    }

    private func play(_ cue: Cue) {
        guard let sound = NSSound(named: cue.soundName)?.copy() as? NSSound else { return }
        sound.volume = 0.35
        sound.play()
    }

    // MARK: - System output mute

    private func muteDefaultOutput() {
        guard let device = Self.defaultOutputDevice(),
              Self.isMuted(device) == false,
              Self.setMuted(true, device: device) else { return }
        mutedOutputDevice = device
    }

    private func restoreOutput() {
        guard let device = mutedOutputDevice else { return }
        _ = Self.setMuted(false, device: device)
        mutedOutputDevice = nil
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        return status == noErr && device != 0 ? device : nil
    }

    private static var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func isMuted(_ device: AudioDeviceID) -> Bool? {
        var address = muteAddress
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var muted = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)
        return status == noErr ? muted != 0 : nil
    }

    private static func setMuted(_ muted: Bool, device: AudioDeviceID) -> Bool {
        var address = muteAddress
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else {
            return false
        }
        var value = UInt32(muted ? 1 : 0)
        let status = AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
        )
        return status == noErr
    }
}
