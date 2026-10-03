import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SummarizerSettings.modelKey) private var model = SummarizerSettings.defaultModel
    @State private var apiKey = Keychain.read(Keychain.openAIKey) ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("OpenAI API key")
                } footer: {
                    Text("Stored in this iPhone's Keychain. Only the transcript text is sent to OpenAI; audio never leaves your phone.")
                }

                Section("Summary model") {
                    TextField(SummarizerSettings.defaultModel, text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Keychain.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: Keychain.openAIKey)
                        dismiss()
                    }
                }
            }
        }
    }
}
