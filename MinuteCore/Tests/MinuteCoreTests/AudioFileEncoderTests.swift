import AVFoundation
import Foundation
import Testing
@testable import MinuteCore

struct AudioFileEncoderTests {
    @Test
    func encodesWavToReadableM4A() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("m4a-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Write a 0.5 s, 16 kHz mono PCM WAV. The file stores 16-bit PCM, but
        // AVAudioFile's processing format is always Float32, so write a Float32 buffer.
        // Scope the writer so the file is closed (header finalized) before encoding.
        let wavURL = dir.appendingPathComponent("in.wav")
        let frames = AVAudioFrameCount(160_000) // 10 s
        do {
            let storeFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!
            let file = try AVAudioFile(forWriting: wavURL, settings: storeFormat.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames)!
            buffer.frameLength = frames
            let channel = buffer.floatChannelData![0]
            for index in 0 ..< Int(frames) {
                channel[index] = Float(0.3 * sin(2.0 * .pi * 440.0 * Double(index) / 16_000.0))
            }
            try file.write(from: buffer)
        }

        let data = try await AudioFileEncoder.encodeToM4AData(sourceURL: wavURL, workingDirectoryURL: dir)
        #expect(!data.isEmpty)
        // Over a 10 s clip the AAC output should be well under the 16-bit PCM source.
        let wavSize = try Data(contentsOf: wavURL).count
        #expect(data.count < wavSize)

        let m4aURL = dir.appendingPathComponent("out.m4a")
        try data.write(to: m4aURL)
        let decoded = try AVAudioFile(forReading: m4aURL)
        #expect(decoded.length > 0)

        // The AVFoundation export path (used for imports) should also produce readable audio.
        let exportedURL = dir.appendingPathComponent("exported.m4a")
        try await AudioFileEncoder.exportToM4A(sourceURL: wavURL, outputURL: exportedURL)
        let exported = try AVAudioFile(forReading: exportedURL)
        #expect(exported.length > 0)
    }
}
