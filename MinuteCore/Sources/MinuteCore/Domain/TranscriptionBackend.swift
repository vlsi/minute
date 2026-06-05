import Foundation

public enum TranscriptionBackend: String, CaseIterable, Sendable, Identifiable {
    case whisper
    case fluidAudio
    case gigaAM

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .whisper:
            return "Whisper"
        case .fluidAudio:
            return "FluidAudio"
        case .gigaAM:
            return "GigaAM"
        }
    }

    public var summary: String {
        switch self {
        case .whisper:
            return "Local transcription via whisper.cpp."
        case .fluidAudio:
            return "Local transcription via Parakeet ASR."
        case .gigaAM:
            return "Local Russian transcription via GigaAM (sherpa-onnx, Apple Silicon)."
        }
    }

    public static func backend(for id: String?) -> TranscriptionBackend {
        guard let id, let backend = TranscriptionBackend(rawValue: id) else {
            return .whisper
        }
        return backend
    }

    public static func displayName(for id: String) -> String {
        backend(for: id).displayName
    }
}
