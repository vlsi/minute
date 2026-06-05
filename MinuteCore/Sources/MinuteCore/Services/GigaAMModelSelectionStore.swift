import Foundation

public final class GigaAMModelSelectionStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = AppConfiguration.Defaults.gigaAMModelIDKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func selectedModelID() -> String? {
        defaults.string(forKey: key)
    }

    public func setSelectedModelID(_ id: String) {
        defaults.set(id, forKey: key)
    }

    public func clearSelectedModelID() {
        defaults.removeObject(forKey: key)
    }

    public func selectedModel() -> GigaAMModel {
        GigaAMModelCatalog.model(for: selectedModelID()) ?? GigaAMModelCatalog.defaultModel
    }
}
