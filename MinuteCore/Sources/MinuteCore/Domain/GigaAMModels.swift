import Foundation

/// Decoder family of a GigaAM sherpa-onnx model.
public enum GigaAMModelKind: String, Sendable, Equatable {
    /// RNN-T transducer: separate encoder, decoder, and joiner graphs.
    case transducer
    /// NeMo CTC: a single graph.
    case ctc
}

/// A single downloadable file that backs a GigaAM model.
public struct GigaAMModelFile: Sendable, Equatable {
    public var fileName: String
    public var sourceURL: URL
    public var expectedSHA256Hex: String
    public var expectedFileSizeBytes: Int64

    public init(fileName: String, sourceURL: URL, expectedSHA256Hex: String, expectedFileSizeBytes: Int64) {
        self.fileName = fileName
        self.sourceURL = sourceURL
        self.expectedSHA256Hex = expectedSHA256Hex
        self.expectedFileSizeBytes = expectedFileSizeBytes
    }
}

/// A GigaAM model variant (Russian, offline) served through sherpa-onnx.
public struct GigaAMModel: Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var summary: String
    /// Sub-directory under `models/gigaam/` that holds this variant's files.
    public var folder: String
    public var kind: GigaAMModelKind
    public var tokens: GigaAMModelFile
    /// Transducer graphs (nil for CTC models).
    public var encoder: GigaAMModelFile?
    public var decoder: GigaAMModelFile?
    public var joiner: GigaAMModelFile?
    /// CTC graph (nil for transducer models).
    public var ctcModel: GigaAMModelFile?

    public init(
        id: String,
        displayName: String,
        summary: String,
        folder: String,
        kind: GigaAMModelKind,
        tokens: GigaAMModelFile,
        encoder: GigaAMModelFile? = nil,
        decoder: GigaAMModelFile? = nil,
        joiner: GigaAMModelFile? = nil,
        ctcModel: GigaAMModelFile? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.folder = folder
        self.kind = kind
        self.tokens = tokens
        self.encoder = encoder
        self.decoder = decoder
        self.joiner = joiner
        self.ctcModel = ctcModel
    }

    /// Every file this variant needs on disk, tokens included.
    public var files: [GigaAMModelFile] {
        [encoder, decoder, joiner, ctcModel, tokens].compactMap { $0 }
    }

    public func destinationURL(for file: GigaAMModelFile) -> URL {
        GigaAMModelPaths.fileURL(folder: folder, fileName: file.fileName)
    }

    public var tokensPath: String { destinationURL(for: tokens).path }
    public var encoderPath: String? { encoder.map { destinationURL(for: $0).path } }
    public var decoderPath: String? { decoder.map { destinationURL(for: $0).path } }
    public var joinerPath: String? { joiner.map { destinationURL(for: $0).path } }
    public var ctcModelPath: String? { ctcModel.map { destinationURL(for: $0).path } }
}

/// On-disk locations for GigaAM model files.
public enum GigaAMModelPaths {
    private static var applicationSupportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
    }

    /// `~/Library/Application Support/Minute/models/gigaam`
    public static var modelsRoot: URL {
        applicationSupportRoot
            .appendingPathComponent("Minute", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("gigaam", isDirectory: true)
    }

    public static func fileURL(folder: String, fileName: String) -> URL {
        var url = modelsRoot
        if !folder.isEmpty {
            url = url.appendingPathComponent(folder, isDirectory: true)
        }
        return url.appendingPathComponent(fileName)
    }

    /// Shared voice-activity-detection model, reused across variants.
    public static var voiceActivityDetectorURL: URL {
        fileURL(folder: "", fileName: "silero_vad.onnx")
    }
}

public enum GigaAMModelCatalog {
    public static let defaultModelID = "gigaam/v3-e2e-rnnt"

    private static let huggingFaceBase =
        "https://huggingface.co/Smirnov75/GigaAM-v3-sherpa-onnx/resolve/main"

    private static func huggingFaceFile(
        _ name: String,
        sha256 sha: String,
        size: Int64
    ) -> GigaAMModelFile {
        GigaAMModelFile(
            fileName: name,
            sourceURL: URL(string: "\(huggingFaceBase)/\(name)")!,
            expectedSHA256Hex: sha,
            expectedFileSizeBytes: size
        )
    }

    /// Silero VAD, used to split long recordings into speech segments.
    public static let voiceActivityDetector = GigaAMModelFile(
        fileName: "silero_vad.onnx",
        sourceURL: URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx")!,
        expectedSHA256Hex: "9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6",
        expectedFileSizeBytes: 643_854
    )

    // GigaAM v3, end-to-end variants (punctuation and inverse text normalisation), Russian, MIT.
    private static let e2eTransducer = GigaAMModel(
        id: "gigaam/v3-e2e-rnnt",
        displayName: "GigaAM v3 (RNN-T)",
        summary: "Russian transcription with punctuation. Highest accuracy, larger download.",
        folder: "v3-e2e-rnnt",
        kind: .transducer,
        tokens: huggingFaceFile("gigaam_v3_e2e_rnnt_tokens.txt",
                                sha256: "7ddf22514c42c531358182c81446a8159771e9921019f09ae743ea622d40221d", size: 13_353),
        encoder: huggingFaceFile("gigaam_v3_e2e_rnnt_encoder.onnx",
                                 sha256: "a1a1bd82caa1507cd9e1e85c7fabf09b96f139640f3f4694de380e3e8a376c6a", size: 885_084_898),
        decoder: huggingFaceFile("gigaam_v3_e2e_rnnt_decoder.onnx",
                                 sha256: "781971998e6a355d6a714f6932a30eab295e7ba0d14fd7e0f78c83b87e811860", size: 4_600_058),
        joiner: huggingFaceFile("gigaam_v3_e2e_rnnt_joint.onnx",
                                sha256: "602ff7017a93311aad34df1437c8d7f49911353c13d6eae7a6ee7b041339465c", size: 2_712_896)
    )

    private static let e2eCTC = GigaAMModel(
        id: "gigaam/v3-e2e-ctc",
        displayName: "GigaAM v3 (CTC)",
        summary: "Russian transcription with punctuation. Faster, slightly lower accuracy.",
        folder: "v3-e2e-ctc",
        kind: .ctc,
        tokens: huggingFaceFile("gigaam_v3_e2e_ctc_tokens.txt",
                                sha256: "f8eb9b115e2748db9c40a5897cae11dd0678cc0b40fd7e25f8c43b3bf28715e4", size: 2_006),
        ctcModel: huggingFaceFile("gigaam_v3_e2e_ctc.onnx",
                                  sha256: "1f3a714b76877724eda494d77e7ed0d15f1c003c60928c9cb03f21d81dc68cc5", size: 885_950_432)
    )

    public static var all: [GigaAMModel] {
        [e2eTransducer, e2eCTC]
    }

    public static var defaultModel: GigaAMModel {
        model(for: defaultModelID) ?? e2eTransducer
    }

    public static func model(for id: String?) -> GigaAMModel? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    public static func displayName(for id: String) -> String {
        model(for: id)?.displayName ?? id
    }
}
