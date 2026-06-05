import Foundation
import Testing
@testable import MinuteCore

struct TranscriptionProgressTests {
    @Test
    func fractionDividesAndClamps() {
        #expect(TranscriptionProgress(processedSeconds: 0, totalSeconds: 100).fractionCompleted == 0)
        #expect(TranscriptionProgress(processedSeconds: 50, totalSeconds: 100).fractionCompleted == 0.5)
        #expect(TranscriptionProgress(processedSeconds: 200, totalSeconds: 100).fractionCompleted == 1)
        #expect(TranscriptionProgress(processedSeconds: 10, totalSeconds: 0).fractionCompleted == 0)
    }

    @Test
    func transcribingProgressCarriesPosition() {
        let progress = PipelineProgress.transcribing(fractionCompleted: 0.5, processedSeconds: 30, totalSeconds: 60)
        #expect(progress.stage == .transcribing)
        #expect(progress.transcriptionProcessedSeconds == 30)
        #expect(progress.transcriptionTotalSeconds == 60)
    }

    @Test
    func transcribingProgressOmitsPositionByDefault() {
        let progress = PipelineProgress.transcribing(fractionCompleted: 0.18)
        #expect(progress.transcriptionProcessedSeconds == nil)
        #expect(progress.transcriptionTotalSeconds == nil)
    }

    @Test
    func clockFormatsMinutesSecondsAndHours() {
        #expect(TranscriptionProgress.clock(0) == "0:00")
        #expect(TranscriptionProgress.clock(5) == "0:05")
        #expect(TranscriptionProgress.clock(125) == "2:05")
        #expect(TranscriptionProgress.clock(3725) == "1:02:05")
    }

    @Test
    func remainingIsHumanReadable() {
        #expect(TranscriptionProgress.remaining(45) == "45s")
        #expect(TranscriptionProgress.remaining(90) == "1m 30s")
        #expect(TranscriptionProgress.remaining(120) == "2m")
        #expect(TranscriptionProgress.remaining(3720) == "1h 2m")
    }

    @Test
    func statusLineShowsPositionOnlyBeforeSpeedStabilises() {
        let line = TranscriptionProgress(processedSeconds: 30, totalSeconds: 60).statusLine(elapsedSeconds: 1)
        #expect(line == "0:30 / 1:00")
    }

    @Test
    func statusLineAddsSpeedAndETA() {
        let line = TranscriptionProgress(processedSeconds: 60, totalSeconds: 120).statusLine(elapsedSeconds: 30)
        #expect(line == "1:00 / 2:00 · 2.0× · ~30s left")
    }
}
