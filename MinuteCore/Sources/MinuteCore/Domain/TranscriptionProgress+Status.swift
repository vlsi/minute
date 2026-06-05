import Foundation

extension TranscriptionProgress {
    /// A compact status line such as `12:30 / 45:00 · 3.2× · ~9m left`.
    ///
    /// Speed (real-time factor) and the ETA are appended only once `elapsedSeconds`
    /// is large enough to be meaningful.
    public func statusLine(elapsedSeconds: Double) -> String {
        var detail = "\(Self.clock(processedSeconds)) / \(Self.clock(totalSeconds))"
        if elapsedSeconds >= 2, processedSeconds > 0, totalSeconds > 0 {
            let speed = processedSeconds / elapsedSeconds
            if speed > 0 {
                detail += String(format: " · %.1f×", speed)
                detail += " · ~\(Self.remaining(max(0, totalSeconds - processedSeconds) / speed)) left"
            }
        }
        return detail
    }

    /// `m:ss`, or `h:mm:ss` past an hour.
    public static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// A human-readable duration such as `45s`, `1m 30s`, `2m`, or `1h 2m`.
    public static func remaining(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        let secs = total % 60
        if minutes < 60 { return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }
}
