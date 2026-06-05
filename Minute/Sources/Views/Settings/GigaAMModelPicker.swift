import Foundation
import MinuteCore
import SwiftUI

struct GigaAMModelPicker: View {
    let models: [GigaAMModel]
    @Binding var selection: String

    var body: some View {
        SettingsMenuField(
            title: "GigaAM model",
            subtitle: selectedModel?.summary,
            options: models,
            selectionLabel: selectedMenuLabel,
            optionLabel: menuLabel(for:),
            isSelected: { $0.id == selection },
            onSelect: { selection = $0.id }
        )
    }

    private var selectedModel: GigaAMModel? {
        models.first { $0.id == selection } ?? models.first
    }

    private var selectedMenuLabel: String {
        guard let selectedModel else { return "Select model" }
        return menuLabel(for: selectedModel)
    }

    private func menuLabel(for model: GigaAMModel) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(model.displayName) (\(formatter.string(fromByteCount: model.downloadSizeBytes)))"
    }
}
