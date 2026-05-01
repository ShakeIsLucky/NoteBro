import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("defaultMeetingType") private var defaultMeetingType = MeetingType.automatic.rawValue
    @AppStorage("defaultModel") private var defaultModel = "anthropic/claude-sonnet-4-6"
    @AppStorage("autoTranscribe") private var autoTranscribe = true
    @AppStorage("autoSummarize") private var autoSummarize = true
    @AppStorage("autoExport") private var autoExport = false
    @AppStorage("obsidianVaultBookmark") private var obsidianVaultBookmark: Data?

    @State private var openAIKey = ""
    @State private var openRouterKey = ""
    @State private var vaultDisplayPath = "Not set"
    @State private var showVaultPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    apiKeysSection
                    modelSection
                    obsidianSection
                    defaultsSection
                    automationSection
                }
                .padding(24)
            }
            .background(NB.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { loadKeys() }
            .fileImporter(
                isPresented: $showVaultPicker,
                allowedContentTypes: [.folder]
            ) { result in
                handleVaultSelection(result)
            }
        }
    }

    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("API Keys")
                .font(.nbSerif(18, weight: .semibold))
                .foregroundStyle(NB.primary)

            keyField(label: "OpenAI API Key", placeholder: "sk-...", text: $openAIKey) {
                try? KeychainService.save(key: "openai_api_key", value: openAIKey)
            }

            keyField(label: "OpenRouter API Key", placeholder: "sk-or-...", text: $openRouterKey) {
                try? KeychainService.save(key: "openrouter_api_key", value: openRouterKey)
            }
        }
        .padding(20)
        .nbCard()
    }

    private func keyField(label: String, placeholder: String, text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.nbSerif(13, weight: .semibold))
                .foregroundStyle(NB.secondary)
            SecureField(placeholder, text: text)
                .font(.nbMono(13))
                .foregroundStyle(NB.primary)
                .padding(12)
                .background(NB.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onSubmit { onCommit() }
                .onChange(of: text.wrappedValue) { onCommit() }
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Default Model")
                .font(.nbSerif(18, weight: .semibold))
                .foregroundStyle(NB.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text("OpenRouter Model ID")
                    .font(.nbSerif(13, weight: .semibold))
                    .foregroundStyle(NB.secondary)
                TextField("anthropic/claude-sonnet-4-6", text: $defaultModel)
                    .font(.nbMono(13))
                    .foregroundStyle(NB.primary)
                    .padding(12)
                    .background(NB.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(20)
        .nbCard()
    }

    private var obsidianSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Obsidian Vault")
                .font(.nbSerif(18, weight: .semibold))
                .foregroundStyle(NB.primary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vault Path")
                        .font(.nbSerif(13, weight: .semibold))
                        .foregroundStyle(NB.secondary)
                    Text(vaultDisplayPath)
                        .font(.nbMono(12))
                        .foregroundStyle(NB.ghost)
                }

                Spacer()

                Button {
                    showVaultPicker = true
                } label: {
                    Text("Select")
                        .nbPill(filled: false)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .nbCard()
        .onAppear { resolveVaultPath() }
    }

    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Defaults")
                .font(.nbSerif(18, weight: .semibold))
                .foregroundStyle(NB.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Default Meeting Type")
                    .font(.nbSerif(13, weight: .semibold))
                    .foregroundStyle(NB.secondary)
                Picker("", selection: $defaultMeetingType) {
                    ForEach(MeetingType.allCases, id: \.rawValue) { type in
                        Text(type.displayName).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(NB.accent)
            }
        }
        .padding(20)
        .nbCard()
    }

    private var automationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Automation")
                .font(.nbSerif(18, weight: .semibold))
                .foregroundStyle(NB.primary)

            settingsToggle("Auto-transcribe after recording", isOn: $autoTranscribe)
            settingsToggle("Auto-summarize after transcription", isOn: $autoSummarize)
            settingsToggle("Auto-export to Obsidian", isOn: $autoExport)
        }
        .padding(20)
        .nbCard()
    }

    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.nbSerif(15))
                .foregroundStyle(NB.primary)
        }
        .tint(NB.accent)
    }

    private func loadKeys() {
        openAIKey = KeychainService.load(key: "openai_api_key") ?? ""
        openRouterKey = KeychainService.load(key: "openrouter_api_key") ?? ""
    }

    private func handleVaultSelection(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
            obsidianVaultBookmark = bookmark
            vaultDisplayPath = url.lastPathComponent
        }
    }

    private func resolveVaultPath() {
        guard let bookmark = obsidianVaultBookmark else { return }
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) {
            vaultDisplayPath = url.lastPathComponent
        }
    }
}
