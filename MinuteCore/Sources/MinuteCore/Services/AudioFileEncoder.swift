import AVFoundation
import AudioToolbox
import Foundation

/// Encodes the contract WAV into a compressed container for vault storage.
enum AudioFileEncoder {
    /// Exports any AVFoundation-readable media (audio or video) to AAC in an `.m4a`
    /// container, preserving the source quality as closely as the preset allows.
    ///
    /// Use this for imported files, where the source may be a video container or a
    /// higher-quality recording than the 16 kHz analysis WAV.
    static func exportToM4A(sourceURL: URL, outputURL: URL) async throws {
        try Task.checkCancellation()

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let asset = AVURLAsset(url: sourceURL)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw MinuteError.audioExportFailed
        }
        export.outputURL = outputURL
        export.outputFileType = .m4a

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    continuation.resume()
                default:
                    continuation.resume(throwing: export.error ?? MinuteError.audioExportFailed)
                }
            }
        }
    }

    /// Encodes a CoreAudio-readable audio file to AAC inside an `.m4a` container.
    static func encodeToM4A(sourceURL: URL, outputURL: URL) async throws {
        try Task.checkCancellation()

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        func check(_ status: OSStatus) throws {
            guard status == noErr else { throw MinuteError.audioExportFailed }
        }

        var inputFile: ExtAudioFileRef?
        try check(ExtAudioFileOpenURL(sourceURL as CFURL, &inputFile))
        guard let inputFile else { throw MinuteError.audioExportFailed }
        defer { ExtAudioFileDispose(inputFile) }

        var fileASBD = AudioStreamBasicDescription()
        var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(ExtAudioFileGetProperty(inputFile, kExtAudioFileProperty_FileDataFormat, &propSize, &fileASBD))

        let sampleRate = fileASBD.mSampleRate > 0 ? fileASBD.mSampleRate : ContractWavVerifier.requiredSampleRate
        let channels = fileASBD.mChannelsPerFrame > 0 ? fileASBD.mChannelsPerFrame : UInt32(ContractWavVerifier.requiredChannels)

        // Client (PCM) format used for both read and write.
        var clientASBD = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2 * channels,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2 * channels,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        let asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(ExtAudioFileSetProperty(inputFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &clientASBD))

        // Destination AAC format. Provide the basics, let CoreAudio fill in the rest.
        var aacASBD = AudioStreamBasicDescription()
        aacASBD.mFormatID = kAudioFormatMPEG4AAC
        aacASBD.mSampleRate = sampleRate
        aacASBD.mChannelsPerFrame = channels
        var aacSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &aacSize, &aacASBD))

        var outputFile: ExtAudioFileRef?
        try check(ExtAudioFileCreateWithURL(
            outputURL as CFURL,
            kAudioFileM4AType,
            &aacASBD,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &outputFile
        ))
        guard let outputFile else { throw MinuteError.audioExportFailed }
        defer { ExtAudioFileDispose(outputFile) }

        try check(ExtAudioFileSetProperty(outputFile, kExtAudioFileProperty_ClientDataFormat, asbdSize, &clientASBD))

        let framesPerChunk: UInt32 = 16_384
        let bytesPerFrame = clientASBD.mBytesPerFrame
        let bufferByteSize = framesPerChunk * bytesPerFrame
        guard let mData = malloc(Int(bufferByteSize)) else { throw MinuteError.audioExportFailed }
        defer { free(mData) }

        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(mNumberChannels: channels, mDataByteSize: bufferByteSize, mData: mData)
        )

        while true {
            try Task.checkCancellation()
            var frames = framesPerChunk
            bufferList.mBuffers.mDataByteSize = bufferByteSize
            try check(ExtAudioFileRead(inputFile, &frames, &bufferList))
            if frames == 0 { break }
            bufferList.mBuffers.mDataByteSize = frames * bytesPerFrame
            try check(ExtAudioFileWrite(outputFile, frames, &bufferList))
        }
    }

    /// Encodes to a temporary `.m4a` inside `workingDirectoryURL` and returns its bytes.
    static func encodeToM4AData(sourceURL: URL, workingDirectoryURL: URL) async throws -> Data {
        try FileManager.default.createDirectory(at: workingDirectoryURL, withIntermediateDirectories: true)
        let outputURL = workingDirectoryURL.appendingPathComponent("vault-audio-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        try await encodeToM4A(sourceURL: sourceURL, outputURL: outputURL)
        return try Data(contentsOf: outputURL)
    }
}
