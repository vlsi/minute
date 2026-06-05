import AVFoundation
import Foundation
import MinuteCore
import SherpaOnnx
import os

/// Russian offline transcription backed by GigaAM models running on sherpa-onnx.
///
/// The recogniser is non-streaming, so long recordings are split into speech
/// segments with Silero VAD; each segment is decoded on its own and emitted as a
/// `TranscriptSegment` with absolute timestamps. Those timestamps let the
/// pipeline attribute text to speakers from the separate diarization pass.
public struct GigaAMTranscriptionService: TranscriptionServicing {
    private let model: GigaAMModel
    private let vadModelPath: String
    private let logger = Logger(subsystem: "roblibob.Minute", category: "gigaam.asr")

    public init(model: GigaAMModel, vadModelPath: String) {
        self.model = model
        self.vadModelPath = vadModelPath
    }

    public static func liveDefault(
        selectionStore: GigaAMModelSelectionStore = GigaAMModelSelectionStore()
    ) -> GigaAMTranscriptionService {
        GigaAMTranscriptionService(
            model: selectionStore.selectedModel(),
            vadModelPath: GigaAMModelPaths.voiceActivityDetectorURL.path
        )
    }

    public func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        try Task.checkCancellation()
        try verifyModelFilesPresent()

        let samples = try Self.readMono16kSamples(from: wavURL)
        logger.debug("GigaAM ASR starting: model=\(model.id, privacy: .public) samples=\(samples.count, privacy: .public)")

        guard let recognizer = makeRecognizer() else {
            throw MinuteError.transcriptionFailed(underlyingDescription: "Failed to create GigaAM recognizer for \(model.id).")
        }
        defer { SherpaOnnxDestroyOfflineRecognizer(recognizer) }

        guard let vad = makeVoiceActivityDetector() else {
            throw MinuteError.transcriptionFailed(underlyingDescription: "Failed to create Silero VAD.")
        }
        defer { SherpaOnnxDestroyVoiceActivityDetector(vad) }

        var segments: [TranscriptSegment] = []
        var textParts: [String] = []

        func drainSpeechSegments() throws {
            while SherpaOnnxVoiceActivityDetectorEmpty(vad) == 0 {
                try Task.checkCancellation()
                guard let segmentPointer = SherpaOnnxVoiceActivityDetectorFront(vad) else { break }
                let startSample = Int(segmentPointer.pointee.start)
                let sampleCount = Int(segmentPointer.pointee.n)
                let segmentSamples = segmentPointer.pointee.samples.map {
                    Array(UnsafeBufferPointer(start: $0, count: sampleCount))
                } ?? []
                SherpaOnnxDestroySpeechSegment(segmentPointer)
                SherpaOnnxVoiceActivityDetectorPop(vad)

                let text = decode(recognizer: recognizer, samples: segmentSamples)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                let startSeconds = Double(startSample) / Double(Self.sampleRate)
                let endSeconds = Double(startSample + sampleCount) / Double(Self.sampleRate)
                segments.append(TranscriptSegment(startSeconds: startSeconds, endSeconds: endSeconds, text: text))
                textParts.append(text)
            }
        }

        let window = Self.vadWindowSize
        var index = 0
        while index + window <= samples.count {
            try Task.checkCancellation()
            let chunk = Array(samples[index ..< index + window])
            SherpaOnnxVoiceActivityDetectorAcceptWaveform(vad, chunk, Int32(window))
            index += window
            try drainSpeechSegments()
        }
        SherpaOnnxVoiceActivityDetectorFlush(vad)
        try drainSpeechSegments()

        logger.debug("GigaAM ASR finished: segments=\(segments.count, privacy: .public)")
        return TranscriptionResult(text: textParts.joined(separator: " "), segments: segments)
    }

    // MARK: - Recognizer

    private func makeRecognizer() -> OpaquePointer? {
        let bag = CStringBag()

        var modelConfig = SherpaOnnxOfflineModelConfig()
        modelConfig.tokens = bag.cString(model.tokensPath)
        modelConfig.num_threads = Int32(Self.threadCount)
        modelConfig.debug = 0
        modelConfig.provider = bag.cString("cpu")

        switch model.kind {
        case .transducer:
            var transducer = SherpaOnnxOfflineTransducerModelConfig()
            transducer.encoder = bag.cString(model.encoderPath ?? "")
            transducer.decoder = bag.cString(model.decoderPath ?? "")
            transducer.joiner = bag.cString(model.joinerPath ?? "")
            modelConfig.transducer = transducer
        case .ctc:
            var nemo = SherpaOnnxOfflineNemoEncDecCtcModelConfig()
            nemo.model = bag.cString(model.ctcModelPath ?? "")
            modelConfig.nemo_ctc = nemo
        }

        var featConfig = SherpaOnnxFeatureConfig()
        featConfig.sample_rate = Int32(Self.sampleRate)
        featConfig.feature_dim = 80

        var config = SherpaOnnxOfflineRecognizerConfig()
        config.feat_config = featConfig
        config.model_config = modelConfig
        config.decoding_method = bag.cString("greedy_search")
        config.max_active_paths = 4

        return withExtendedLifetime(bag) {
            SherpaOnnxCreateOfflineRecognizer(&config)
        }
    }

    private func decode(recognizer: OpaquePointer, samples: [Float]) -> String {
        guard !samples.isEmpty, let stream = SherpaOnnxCreateOfflineStream(recognizer) else { return "" }
        defer { SherpaOnnxDestroyOfflineStream(stream) }

        SherpaOnnxAcceptWaveformOffline(stream, Int32(Self.sampleRate), samples, Int32(samples.count))
        SherpaOnnxDecodeOfflineStream(recognizer, stream)

        guard let resultPointer = SherpaOnnxGetOfflineStreamResult(stream) else { return "" }
        defer { SherpaOnnxDestroyOfflineRecognizerResult(resultPointer) }
        guard let cText = resultPointer.pointee.text else { return "" }
        return String(cString: cText)
    }

    // MARK: - VAD

    private func makeVoiceActivityDetector() -> OpaquePointer? {
        let bag = CStringBag()

        var silero = SherpaOnnxSileroVadModelConfig()
        silero.model = bag.cString(vadModelPath)
        silero.threshold = 0.5
        silero.min_silence_duration = 0.5
        silero.min_speech_duration = 0.25
        silero.window_size = Int32(Self.vadWindowSize)
        // Offline GigaAM handles long utterances; keep segments bounded for memory and timing.
        silero.max_speech_duration = 20.0

        var vadConfig = SherpaOnnxVadModelConfig()
        vadConfig.silero_vad = silero
        vadConfig.sample_rate = Int32(Self.sampleRate)
        vadConfig.num_threads = 1
        vadConfig.provider = bag.cString("cpu")

        return withExtendedLifetime(bag) {
            SherpaOnnxCreateVoiceActivityDetector(&vadConfig, 30)
        }
    }

    // MARK: - Helpers

    private func verifyModelFilesPresent() throws {
        let fileManager = FileManager.default
        var required = model.files.map { model.destinationURL(for: $0).path }
        required.append(vadModelPath)
        let missing = required.filter { !fileManager.fileExists(atPath: $0) }
        guard missing.isEmpty else {
            throw MinuteError.transcriptionFailed(
                underlyingDescription: "GigaAM model files missing: \(missing.joined(separator: ", "))."
            )
        }
    }

    static let sampleRate = 16_000
    static let vadWindowSize = 512

    static var threadCount: Int {
        min(8, max(2, ProcessInfo.processInfo.activeProcessorCount - 2))
    }

    /// Reads an audio file as mono 16 kHz Float samples, resampling if needed.
    static func readMono16kSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else {
            throw MinuteError.transcriptionFailed(underlyingDescription: "Failed to build 16 kHz output format.")
        }

        let inputFormat = file.processingFormat
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw MinuteError.transcriptionFailed(underlyingDescription: "Failed to create audio converter.")
        }

        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(file.length) * ratio).rounded(.up)) + AVAudioFrameCount(outputFormat.sampleRate)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: max(capacity, 1)) else {
            throw MinuteError.transcriptionFailed(underlyingDescription: "Failed to allocate output buffer.")
        }

        let feeder = AudioConverterFeeder(file: file, format: inputFormat)
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError, withInputFrom: feeder.provide)
        if status == .error, let conversionError {
            throw MinuteError.transcriptionFailed(underlyingDescription: "Audio conversion failed: \(conversionError.localizedDescription)")
        }

        guard let channel = outputBuffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(outputBuffer.frameLength)))
    }
}

/// Feeds an `AVAudioFile` into an `AVAudioConverter` one block at a time.
///
/// The converter input callback is `@Sendable`, so the read cursor lives in a
/// reference type rather than a captured `var`. Conversion is synchronous and
/// single-threaded, hence `@unchecked Sendable`.
private final class AudioConverterFeeder: @unchecked Sendable {
    private let file: AVAudioFile
    private let format: AVAudioFormat
    private var finished = false

    init(file: AVAudioFile, format: AVAudioFormat) {
        self.file = file
        self.format = format
    }

    func provide(
        _ packetCount: AVAudioPacketCount,
        _ outStatus: UnsafeMutablePointer<AVAudioConverterInputStatus>
    ) -> AVAudioPCMBuffer? {
        if finished {
            outStatus.pointee = .endOfStream
            return nil
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384) else {
            outStatus.pointee = .endOfStream
            finished = true
            return nil
        }
        do {
            try file.read(into: buffer)
        } catch {
            outStatus.pointee = .endOfStream
            finished = true
            return nil
        }
        if buffer.frameLength == 0 {
            outStatus.pointee = .endOfStream
            finished = true
            return nil
        }
        outStatus.pointee = .haveData
        return buffer
    }
}

/// Holds `strdup`-ed C strings alive for the duration of a config build.
private final class CStringBag {
    private var pointers: [UnsafeMutablePointer<CChar>] = []

    func cString(_ string: String) -> UnsafePointer<CChar>? {
        guard let pointer = strdup(string) else { return nil }
        pointers.append(pointer)
        return UnsafePointer(pointer)
    }

    deinit {
        for pointer in pointers { free(pointer) }
    }
}
