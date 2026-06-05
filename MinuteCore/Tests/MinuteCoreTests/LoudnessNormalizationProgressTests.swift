import Foundation
import Testing
@testable import MinuteCore

struct LoudnessNormalizationProgressTests {
    @Test
    func parsesOutTimeLines() {
        #expect(AudioLoudnessNormalizer.parseOutTimeSeconds("out_time=00:00:30.000000") == 30)
        #expect(AudioLoudnessNormalizer.parseOutTimeSeconds("out_time=01:02:03.000000") == 3723)
        #expect(AudioLoudnessNormalizer.parseOutTimeSeconds("out_time=N/A") == nil)
        #expect(AudioLoudnessNormalizer.parseOutTimeSeconds("frame=10") == nil)
    }

    @Test
    func overallFractionSpansBothPasses() {
        #expect(LoudnessNormalizationProgress(passIndex: 0, totalPasses: 2, processedSeconds: 30)
            .overallFraction(totalSeconds: 60) == 0.25)
        #expect(LoudnessNormalizationProgress(passIndex: 1, totalPasses: 2, processedSeconds: 30)
            .overallFraction(totalSeconds: 60) == 0.75)
        #expect(LoudnessNormalizationProgress(passIndex: 1, totalPasses: 2, processedSeconds: 120)
            .overallFraction(totalSeconds: 60) == 1.0)
    }
}
