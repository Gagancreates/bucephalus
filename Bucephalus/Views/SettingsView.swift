import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.provider) private var providerRaw = Provider.openai.rawValue
    @AppStorage(SettingsKeys.autoTitle) private var autoTitle = true

    @State private var keys: [Provider: String] = Dictionary(
        uniqueKeysWithValues: Provider.allCases.map { ($0, Keychain.read($0.keychainAccount) ?? "") }
    )
    @State private var chosenModels: [Provider: String] = Dictionary(
        uniqueKeysWithValues: Provider.allCases.map { ($0, $0.selectedModel) }
    )
    @State private var models: [ModelInfo] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private var provider: Provider { Provider(rawValue: providerRaw) ?? .openai }
    private var currentKey: String {
        (keys[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var keyBinding: Binding<String> {
        Binding(get: { keys[provider] ?? "" }, set: { keys[provider] = $0 })
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { chosenModels[provider] ?? provider.defaultModel },
            set: {
                chosenModels[provider] = $0
                UserDefaults.standard.set($0, forKey: provider.modelKey)
            }
        )
    }

    // The saved choice stays selectable even before (or without) a fetched list.
    private var modelOptions: [ModelInfo] {
        let selected = modelBinding.wrappedValue
        if models.contains(where: { $0.id == selected }) { return models }
        return [ModelInfo(id: selected, name: selected)] + models
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $providerRaw) {
                        ForEach(Provider.allCases) { Text($0.displayName).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    SecureField(provider.keyPlaceholder, text: keyBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("\(provider.displayName) API key")
                } footer: {
                    Text("Stored in this iPhone's Keychain. Only the transcript text is sent to \(provider.displayName); audio never leaves your phone.")
                }

                Section {
                    Picker("Model", selection: modelBinding) {
                        ForEach(modelOptions) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    modelFooter
                }

                Section {
                    Toggle("Name meetings automatically", isOn: $autoTitle)
                        .tint(.green)
                } footer: {
                    Text("The model writes a heading of up to 5 words from the conversation.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: "\(providerRaw)|\(currentKey)") { await loadModels() }
            .onDisappear(perform: saveKeys)
        }
    }

    @ViewBuilder
    private var modelFooter: some View {
        if currentKey.isEmpty {
            Text("Add an API key to load the list of models.")
        } else if isLoading {
            Text("Loading models…")
        } else if let loadError {
            Text("Couldn't load models: \(loadError)")
        }
    }

    private func loadModels() async {
        models = []
        loadError = nil
        let key = currentKey
        guard !key.isEmpty else { return }
        // Wait for typing or pasting to settle before hitting the API.
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await LLMClient(provider: provider, apiKey: key).listModels()
            guard !Task.isCancelled else { return }
            models = loaded
        } catch {
            if !Task.isCancelled { loadError = error.localizedDescription }
        }
    }

    private func saveKeys() {
        for (provider, key) in keys {
            Keychain.save(key.trimmingCharacters(in: .whitespacesAndNewlines), for: provider.keychainAccount)
        }
    }
}
