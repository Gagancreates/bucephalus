import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var meetings: [Meeting]

    @AppStorage(SettingsKeys.provider) private var providerRaw = Provider.openai.rawValue
    @AppStorage(SettingsKeys.autoTitle) private var autoTitle = true
    @AppStorage(AppSettings.summaryStyle) private var summaryStyleRaw = SummaryStyle.standard.rawValue
    @AppStorage(AppSettings.customInstructions) private var customInstructions = ""
    @AppStorage(AppSettings.audioQuality) private var audioQualityRaw = AudioQuality.standard.rawValue
    @AppStorage(AppSettings.keepAudio) private var keepAudio = true
    @AppStorage(AppSettings.appearance) private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(AppSettings.accent) private var accentRaw = AccentChoice.maroon.rawValue

    @State private var keys: [Provider: String] = Dictionary(
        uniqueKeysWithValues: Provider.allCases.map { ($0, Keychain.read($0.keychainAccount) ?? "") }
    )
    @State private var chosenModels: [Provider: String] = Dictionary(
        uniqueKeysWithValues: Provider.allCases.map { ($0, $0.selectedModel) }
    )
    @State private var models: [ModelInfo] = []
    @State private var isLoading = false
    @State private var loadError: String?

    @State private var storage = StorageInfo()
    @State private var exportFiles: ExportFiles?
    @State private var confirmingDeleteAll = false

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
                aiSection
                transcriptionSection
                recordingSection
                storageSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: "\(providerRaw)|\(currentKey)") { await loadModels() }
            .task { storage = await StorageInfo.load(meetingCount: meetings.count) }
            .onDisappear(perform: saveKeys)
            .sheet(item: $exportFiles) { ShareSheet(items: $0.urls) }
            .confirmationDialog("Delete all meetings?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete \(meetings.count) meetings", role: .destructive, action: deleteAll)
            } message: {
                Text("Every recording, transcript, summary and note on this iPhone will be removed. This can't be undone.")
            }
        }
    }

    // MARK: AI & summaries

    @ViewBuilder
    private var aiSection: some View {
        Section {
            Picker("Provider", selection: $providerRaw) {
                ForEach(Provider.allCases) { Text($0.displayName).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Text("AI & summaries")
        }

        Section {
            SecureField(provider.keyPlaceholder, text: keyBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Picker("Model", selection: modelBinding) {
                ForEach(modelOptions) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("\(provider.displayName) API key")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stored in this iPhone's Keychain. Only the transcript text is sent to \(provider.displayName); audio never leaves your phone.")
                modelStatus
            }
        }

        Section {
            Picker("Summary style", selection: $summaryStyleRaw) {
                ForEach(SummaryStyle.allCases) { Text($0.name).tag($0.rawValue) }
            }
            if summaryStyleRaw == SummaryStyle.custom.rawValue {
                TextField("e.g. Focus on decisions and deadlines. Use British spelling.",
                          text: $customInstructions, axis: .vertical)
                    .lineLimit(3...)
            }
            Toggle("Name meetings automatically", isOn: $autoTitle)
                .tint(.green)
        } footer: {
            Text("Applies to new summaries. Automatic names are up to 5 words and never replace a name you typed.")
        }
    }

    @ViewBuilder
    private var modelStatus: some View {
        if currentKey.isEmpty {
            Text("Add an API key to load the list of models.")
        } else if isLoading {
            Text("Loading models…")
        } else if let loadError {
            Text("Couldn't load models: \(loadError)")
        }
    }

    // MARK: Transcription

    private var transcriptionSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parakeet v2")
                    Text("English, runs on this iPhone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                modelState
            }
        } header: {
            Text("Transcription")
        } footer: {
            Text("A one-time download of about 450 MB; after that, transcription works offline. Until it's downloaded, Apple's built-in engine is used, which struggles with distant voices.")
        }
    }

    @ViewBuilder
    private var modelState: some View {
        switch SpeechModelStatus.shared.state {
        case .ready:
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.subheadline)
                .foregroundStyle(.green)
        case .downloading(let fraction):
            HStack(spacing: 8) {
                ProgressView(value: fraction)
                    .frame(width: 60)
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .notDownloaded, .failed:
            Button("Download") {
                SpeechModelStatus.shared.state = .downloading(0)
                Task { try? await ParakeetTranscriber.shared.prepare() }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: Recording

    private var recordingSection: some View {
        Section {
            Picker("Audio quality", selection: $audioQualityRaw) {
                ForEach(AudioQuality.allCases) { quality in
                    Text(quality.name).tag(quality.rawValue)
                }
            }
            Toggle("Keep audio after transcribing", isOn: $keepAudio)
                .tint(.green)
            NavigationLink {
                ActionButtonHelpView()
            } label: {
                Label("Action Button & Siri", systemImage: "button.horizontal.top.press")
            }
        } header: {
            Text("Recording")
        } footer: {
            Text("\(AudioQuality(rawValue: audioQualityRaw)?.detail ?? ""). \(keepAudio ? "Recordings are kept, so meetings can be re-transcribed." : "Recordings are deleted once a meeting is summarised, which saves space but means it can't be re-transcribed.")")
        }
    }

    // MARK: Storage & backup

    private var storageSection: some View {
        Section {
            LabeledContent("Meetings", value: "\(meetings.count)")
            LabeledContent("Recordings", value: storage.audioSize)
            LabeledContent("Backups", value: storage.backupSummary)
            Button("Export all meetings", systemImage: "square.and.arrow.up") {
                exportFiles = ExportFiles(urls: MeetingExporter.export(meetings))
            }
            .disabled(meetings.isEmpty)
            Button("Delete all meetings", systemImage: "trash", role: .destructive) {
                confirmingDeleteAll = true
            }
            .disabled(meetings.isEmpty)
        } header: {
            Text("Storage & backup")
        } footer: {
            Text("Everything lives on this iPhone. The app keeps a daily copy of your meetings in case an update goes wrong; export saves each meeting as a Markdown file you can keep in Files or iCloud Drive.")
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearanceRaw) {
                ForEach(Appearance.allCases) { Text($0.name).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 0) {
                Text("Accent")
                Spacer()
                HStack(spacing: 14) {
                    ForEach(AccentChoice.allCases) { choice in
                        Button {
                            accentRaw = choice.rawValue
                        } label: {
                            Circle()
                                .fill(choice.color)
                                .frame(width: 26, height: 26)
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 2)
                                        .padding(-4)
                                        .opacity(accentRaw == choice.rawValue ? 1 : 0)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(choice.name)
                        .accessibilityAddTraits(accentRaw == choice.rawValue ? .isSelected : [])
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
            Link(destination: URL(string: "https://github.com/Gagancreates/bucephalus")!) {
                Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    // MARK: Actions

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

    private func deleteAll() {
        for meeting in meetings {
            try? FileManager.default.removeItem(at: meeting.audioURL)
            modelContext.delete(meeting)
        }
        try? modelContext.save()
        Task { storage = await StorageInfo.load(meetingCount: 0) }
    }
}

// MARK: - Action Button help

private struct ActionButtonHelpView: View {
    var body: some View {
        List {
            Section {
                step(1, "Open the **Settings** app and tap **Action Button**.")
                step(2, "Swipe to **Shortcut**, then tap **Choose a Shortcut**.")
                step(3, "Pick **Bucephalus**, then **Record or Stop**.")
            } header: {
                Text("Action Button")
            } footer: {
                Text("Press once to start recording, press again to stop. It works from the lock screen, and the recording shows on your lock screen and in the Dynamic Island.")
            }

            Section {
                Text("“Record with Bucephalus”")
                Text("“Stop Bucephalus”")
            } header: {
                Text("Siri")
            }

            Section {
                Text("Long-press the lock screen, tap **Customize**, then **Lock Screen**. Swap the flashlight or camera button for **Bucephalus › Record**, or add the round Record widget.")
            } header: {
                Text("Lock screen and Control Center")
            }
        }
        .navigationTitle("Action Button & Siri")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 22, height: 22)
                .background(Theme.accent, in: .circle)
            Text(text)
        }
    }
}

// MARK: - Storage info

private struct StorageInfo {
    var audioSize = "–"
    var backupSummary = "–"

    static func load(meetingCount: Int) async -> StorageInfo {
        let files = FileManager.default
        let audioFiles = (try? files.contentsOfDirectory(at: .documentsDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let bytes = audioFiles
            .filter { $0.pathExtension == "caf" }
            .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
            .reduce(0, +)

        let backupsFolder = URL.applicationSupportDirectory.appending(path: "StoreBackups")
        let backups = ((try? files.contentsOfDirectory(atPath: backupsFolder.path)) ?? []).sorted()
        let latest = backups.last.flatMap { try? Date($0, strategy: .iso8601.year().month().day()) }

        var info = StorageInfo()
        info.audioSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        if backups.isEmpty {
            info.backupSummary = "None yet"
        } else {
            let when = latest.map { $0.formatted(.relative(presentation: .named)) } ?? ""
            info.backupSummary = "\(backups.count) daily, latest \(when)"
        }
        return info
    }
}

// MARK: - Export

private struct ExportFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}

enum MeetingExporter {
    /// Writes one Markdown file per meeting into a fresh temporary folder and returns their URLs.
    static func export(_ meetings: [Meeting]) -> [URL] {
        let folder = URL.temporaryDirectory.appending(path: "Bucephalus Export \(UUID().uuidString.prefix(6))")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var usedNames: Set<String> = []

        return meetings.sorted { $0.createdAt > $1.createdAt }.compactMap { meeting in
            let date = meeting.createdAt.formatted(.iso8601.year().month().day())
            var name = "\(date) \(meeting.title)".replacingOccurrences(of: "/", with: "-")
            while usedNames.contains(name) { name += " (2)" }
            usedNames.insert(name)
            let url = folder.appending(path: "\(name).md")
            do {
                try markdown(for: meeting).write(to: url, atomically: true, encoding: .utf8)
                return url
            } catch {
                return nil
            }
        }
    }

    static func markdown(for meeting: Meeting) -> String {
        let named = meeting.resolvingSpeakerNames
        var lines = [
            "# \(meeting.title)",
            "",
            "\(meeting.createdAt.formatted(date: .long, time: .shortened)) · \(meeting.duration.shortDurationString)",
        ]
        if let summary = meeting.summary {
            lines += ["", "## Summary", "", named(summary.overview)]
            for (title, items) in [("Key points", summary.keyPoints), ("Decisions", summary.decisions), ("Action items", summary.actionItems)]
            where !items.isEmpty {
                lines += ["", "### \(title)", ""] + items.map { "- \(named($0))" }
            }
        }
        if !meeting.notes.isEmpty {
            lines += ["", "## Notes", "", meeting.notes]
        }
        if let segments = meeting.segments, meeting.hasSpeakers {
            lines += ["", "## Transcript", ""]
            for segment in segments {
                let who = segment.speaker.map { meeting.name(for: $0) } ?? "Unknown"
                lines += ["**\(who)** (\(segment.start.clockString)): \(segment.text)", ""]
            }
        } else if let transcript = meeting.transcript {
            lines += ["", "## Transcript", "", transcript]
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
