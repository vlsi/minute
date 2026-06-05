import Foundation

/// Container format for the audio saved into the vault.
public enum AudioStorageFormat: String, CaseIterable, Sendable, Identifiable, Codable {
    /// Uncompressed 16 kHz mono PCM (the recorded contract WAV, verbatim).
    case wav
    /// AAC in an MPEG-4 container — roughly an order of magnitude smaller.
    case m4a

    public var id: String { rawValue }

    public var fileExtension: String { rawValue }

    public var displayName: String {
        switch self {
        case .wav:
            return "WAV (uncompressed)"
        case .m4a:
            return "M4A (AAC, smaller)"
        }
    }

    public static func resolved(from rawValue: String?) -> AudioStorageFormat {
        guard let rawValue, let value = AudioStorageFormat(rawValue: rawValue) else {
            return AppConfiguration.Defaults.defaultAudioStorageFormat
        }
        return value
    }
}
