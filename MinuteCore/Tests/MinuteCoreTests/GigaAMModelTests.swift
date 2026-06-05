import Foundation
import Testing
@testable import MinuteCore

struct GigaAMModelTests {
    @Test
    func backendIncludesGigaAM() {
        #expect(TranscriptionBackend.allCases.contains(.gigaAM))
        #expect(TranscriptionBackend.gigaAM.displayName == "GigaAM")
    }

    @Test
    func selectionDefaultsToTransducer() {
        let suite = "minute-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = GigaAMModelSelectionStore(defaults: defaults, key: "gigaam-model")

        #expect(store.selectedModel().id == GigaAMModelCatalog.defaultModelID)
        #expect(store.selectedModel().id == "gigaam/v3-e2e-rnnt")
        #expect(store.selectedModel().kind == .transducer)
    }

    @Test
    func catalogHasTransducerAndCTCVariants() {
        let ids = GigaAMModelCatalog.all.map(\.id)
        #expect(ids.contains("gigaam/v3-e2e-rnnt"))
        #expect(ids.contains("gigaam/v3-e2e-ctc"))

        let transducer = GigaAMModelCatalog.model(for: "gigaam/v3-e2e-rnnt")
        #expect(transducer?.encoder != nil)
        #expect(transducer?.decoder != nil)
        #expect(transducer?.joiner != nil)
        #expect(transducer?.ctcModel == nil)

        let ctc = GigaAMModelCatalog.model(for: "gigaam/v3-e2e-ctc")
        #expect(ctc?.kind == .ctc)
        #expect(ctc?.ctcModel != nil)
        #expect(ctc?.encoder == nil)
    }

    @Test
    func modelFilesLiveUnderGigaamFolder() {
        let model = GigaAMModelCatalog.defaultModel
        let tokensURL = model.destinationURL(for: model.tokens)
        #expect(tokensURL.path.contains("/Minute/models/gigaam/v3-e2e-rnnt/"))
        #expect(GigaAMModelPaths.voiceActivityDetectorURL.path.hasSuffix("/Minute/models/gigaam/silero_vad.onnx"))
    }

    @Test
    func requiredModelsForGigaAMIncludeAllFilesAndVAD() {
        let specs = DefaultModelManager.defaultRequiredModels(
            summarizationProvider: .ollama,
            visionProvider: .ollama,
            screenContextEnabled: false,
            selectedGigaAMModelID: "gigaam/v3-e2e-rnnt",
            transcriptionBackend: .gigaAM
        )
        let ids = specs.map(\.id)

        #expect(ids.contains("gigaam/v3-e2e-rnnt/gigaam_v3_e2e_rnnt_encoder.onnx"))
        #expect(ids.contains("gigaam/v3-e2e-rnnt/gigaam_v3_e2e_rnnt_decoder.onnx"))
        #expect(ids.contains("gigaam/v3-e2e-rnnt/gigaam_v3_e2e_rnnt_joint.onnx"))
        #expect(ids.contains("gigaam/v3-e2e-rnnt/gigaam_v3_e2e_rnnt_tokens.txt"))
        #expect(ids.contains("gigaam/silero_vad.onnx"))

        for spec in specs where spec.id.hasPrefix("gigaam") {
            #expect(spec.expectedSHA256Hex.count == 64)
            #expect(spec.sourceURL.scheme == "https")
            #expect((spec.expectedFileSizeBytes ?? 0) > 0)
        }
    }

    @Test
    func whisperBackendDoesNotPullGigaAMFiles() {
        let specs = DefaultModelManager.defaultRequiredModels(
            summarizationProvider: .ollama,
            visionProvider: .ollama,
            screenContextEnabled: false,
            transcriptionBackend: .whisper
        )
        #expect(!specs.contains { $0.id.hasPrefix("gigaam") })
    }
}
