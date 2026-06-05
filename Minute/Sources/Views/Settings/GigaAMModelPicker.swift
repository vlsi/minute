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
            selectionLabel: selectedLabel,
            optionLabel: { $0.displayName },
            isSelected: { $0.id == selection },
            onSelect: { selection = $0.id }
        )
    }

    private var selectedModel: GigaAMModel? {
        models.first { $0.id == selection } ?? models.first
    }

    private var selectedLabel: String {
        selectedModel?.displayName ?? "Select model"
    }
}
