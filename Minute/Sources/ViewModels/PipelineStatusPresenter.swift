import Foundation
import MinuteCore

struct PipelineStatusPresenter {
    struct Input {
        var state: MeetingPipelineState
        var backgroundProcessingSnapshot: BackgroundProcessingSnapshot
        var isFirstScreenInferenceDeferred: Bool
        var progress: Double?
        var statusLabelOverride: String?
        var recoverableRecordings: [RecoverableRecording]
        var recordingWarningDetail: String?
        var summarizationProgressDetail: String?
        var transcriptionProgressDetail: String?
    }

    enum Action: Equatable {
        case keepRecording
        case cancelBackgroundProcessing(clearPending: Bool)
        case retryBackgroundProcessing
        case recoverRecording(RecoverableRecording)
        case discardRecoverableRecording(RecoverableRecording)
        case process
        case revealInFinder(URL)
    }

    struct Presentation: Equatable {
        var title: String
        var detail: String
        var progress: Double?
        var showsActivity: Bool
        var isError: Bool
        var primaryActionTitle: String?
        var primaryAction: Action?
        var secondaryActionTitle: String?
        var secondaryAction: Action?
        var showsCloseButton: Bool
    }

    func presentation(for input: Input, dismissedStatusDrawerID: String?) -> Presentation? {
        if let dismissibleID = dismissibleStatusDrawerID(for: input.state),
           dismissibleID == dismissedStatusDrawerID {
            return nil
        }

        if case .recording = input.state,
           let warningDetail = input.recordingWarningDetail {
            return Presentation(
                title: "Do you want to keep recording?",
                detail: warningDetail,
                progress: nil,
                showsActivity: false,
                isError: true,
                primaryActionTitle: "Keep Recording",
                primaryAction: .keepRecording,
                secondaryActionTitle: nil,
                secondaryAction: nil,
                showsCloseButton: false
            )
        }

        if input.backgroundProcessingSnapshot.activeMeetingID != nil {
            let stage = input.backgroundProcessingSnapshot.activeStage
            let progress = input.backgroundProcessingSnapshot.activeProgress
            let hasPending = input.backgroundProcessingSnapshot.pendingMeetingID != nil

            let title: String
            switch stage {
            case .downloadingModels:
                title = "Downloading Models"
            case .normalizingAudioLevels:
                title = "Normalizing Audio Levels"
            case .transcribing:
                title = "Transcribing"
            case .summarizing:
                title = "Summarizing"
            case .writing:
                title = "Writing"
            case nil:
                title = "Processing"
            }

            let baseDetail = input.isFirstScreenInferenceDeferred
                ? "Your recorded meeting is processing. Screen context disabled until processing is done."
                : "Your recorded meeting is processing in the background."
            let detail = hasPending
                ? baseDetail + " Another meeting is pending next."
                : baseDetail
            let detailWithSummarization: String
            if stage == .summarizing,
               let summarizationProgressDetail = input.summarizationProgressDetail {
                detailWithSummarization = detail + " " + summarizationProgressDetail
            } else {
                detailWithSummarization = detail
            }

            return Presentation(
                title: title,
                detail: detailWithSummarization,
                progress: progress,
                showsActivity: progress == nil,
                isError: false,
                primaryActionTitle: "Cancel",
                primaryAction: .cancelBackgroundProcessing(clearPending: true),
                secondaryActionTitle: nil,
                secondaryAction: nil,
                showsCloseButton: false
            )
        }

        if case .idle = input.state {
            switch input.backgroundProcessingSnapshot.lastOutcome {
            case .failed(let message):
                return Presentation(
                    title: "Processing failed",
                    detail: message,
                    progress: nil,
                    showsActivity: false,
                    isError: true,
                    primaryActionTitle: "Retry",
                    primaryAction: .retryBackgroundProcessing,
                    secondaryActionTitle: nil,
                    secondaryAction: nil,
                    showsCloseButton: false
                )
            case .canceled:
                return Presentation(
                    title: "Processing was canceled",
                    detail: "You can retry this meeting later.",
                    progress: nil,
                    showsActivity: false,
                    isError: false,
                    primaryActionTitle: "Retry",
                    primaryAction: .retryBackgroundProcessing,
                    secondaryActionTitle: nil,
                    secondaryAction: nil,
                    showsCloseButton: false
                )
            case .completed, nil:
                break
            }
        }

        if case .idle = input.state,
           let recovery = input.recoverableRecordings.first {
            let folderName = recovery.sessionURL.lastPathComponent
            return Presentation(
                title: "Unfinished meeting found",
                detail: "An unfinished meeting was found in \(folderName). Do you want to recover it?",
                progress: nil,
                showsActivity: false,
                isError: false,
                primaryActionTitle: "Recover",
                primaryAction: .recoverRecording(recovery),
                secondaryActionTitle: "Delete",
                secondaryAction: .discardRecoverableRecording(recovery),
                showsCloseButton: false
            )
        }

        switch input.state {
        case .recorded:
            return Presentation(
                title: "Recording ready",
                detail: "This meeting is ready to process.",
                progress: nil,
                showsActivity: false,
                isError: false,
                primaryActionTitle: "Process",
                primaryAction: .process,
                secondaryActionTitle: nil,
                secondaryAction: nil,
                showsCloseButton: false
            )
        case .processing, .writing, .importing:
            return Presentation(
                title: input.statusLabelOverride ?? input.state.statusLabel,
                detail: input.transcriptionProgressDetail ?? "Meeting is being processed.",
                progress: input.progress,
                showsActivity: input.progress == nil,
                isError: false,
                primaryActionTitle: nil,
                primaryAction: nil,
                secondaryActionTitle: nil,
                secondaryAction: nil,
                showsCloseButton: false
            )
        case .done(let noteURL, _):
            return Presentation(
                title: "Meeting ready",
                detail: "Your note, transcript, and audio are in the vault.",
                progress: nil,
                showsActivity: false,
                isError: false,
                primaryActionTitle: "Reveal in Finder",
                primaryAction: .revealInFinder(noteURL),
                secondaryActionTitle: nil,
                secondaryAction: nil,
                showsCloseButton: true
            )
        case .failed(let error, _):
            return Presentation(
                title: "Processing failed",
                detail: ErrorHandler.userMessage(for: error, fallback: "Processing failed."),
                progress: nil,
                showsActivity: false,
                isError: true,
                primaryActionTitle: nil,
                primaryAction: nil,
                secondaryActionTitle: nil,
                secondaryAction: nil,
                showsCloseButton: true
            )
        default:
            return nil
        }
    }

    func dismissibleStatusDrawerID(for state: MeetingPipelineState) -> String? {
        switch state {
        case .recorded(let audioTempURL, _, let startedAt, let stoppedAt):
            return "recorded:\(audioTempURL.path):\(startedAt.timeIntervalSinceReferenceDate):\(stoppedAt.timeIntervalSinceReferenceDate)"
        case .done(let noteURL, _):
            return "done:\(noteURL.path)"
        default:
            return nil
        }
    }
}
