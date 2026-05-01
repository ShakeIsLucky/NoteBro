import SwiftUI
import SwiftData

enum DetailTab: String, CaseIterable {
    case summary = "Summary"
    case transcript = "Transcript"
    case notes = "Notes"
}

struct MeetingDetailView: View {
    @Bindable var meeting: Meeting
    @State private var selectedTab: DetailTab = .summary
    @State private var transcriber = TranscriptionService()
    @State private var summarizer = SummarizationService()
    @State private var resummarizeType: MeetingType = .automatic
    @State private var customPrompt = ""
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    @AppStorage("autoSummarize") private var autoSummarize = true
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            tabPicker
            tabContent
            actionBar
        }
        .background(NB.bg)
        .navigationBarTitleDisplayMode(.inline)
        .task { await autoProcess() }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Delete Meeting?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(meeting)
                dismiss()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Meeting name", text: $meeting.name)
                .font(.nbSerif(24, weight: .bold))
                .foregroundStyle(NB.primary)

            HStack(spacing: 10) {
                Text(meeting.formattedDate)
                    .font(.nbMono(12))
                    .foregroundStyle(NB.secondary)
                Text("·")
                    .foregroundStyle(NB.ghost)
                Text(meeting.formattedDuration)
                    .font(.nbMono(12))
                    .foregroundStyle(NB.secondary)

                Text(meeting.meetingTypeEnum.displayName)
                    .font(.nbSerif(11, weight: .medium))
                    .foregroundStyle(NB.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(NB.accentDim)
                    .clipShape(Capsule())
            }

            if transcriber.isTranscribing || summarizer.isSummarizing {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(NB.accent)
                    Text(transcriber.isTranscribing ? "Transcribing..." : "Summarizing...")
                        .font(.nbSerif(13))
                        .foregroundStyle(NB.secondary)
                    if transcriber.isTranscribing {
                        Text("\(Int(transcriber.progress * 100))%")
                            .font(.nbMono(11))
                            .foregroundStyle(NB.accent)
                    }
                }
            }
        }
        .padding(20)
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.25)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.nbSerif(14, weight: .medium))
                        .foregroundStyle(selectedTab == tab ? NB.bg : NB.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? NB.accent : NB.surface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            switch selectedTab {
            case .summary: summaryTab
            case .transcript: transcriptTab
            case .notes: notesTab
            }
        }
    }

    private var summaryTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            if summarizer.isSummarizing && !summarizer.streamedContent.isEmpty {
                Text(summarizer.streamedContent)
                    .font(.nbSerif(15))
                    .foregroundStyle(NB.primary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .nbCard()
            } else if let summary = meeting.summary, !summary.isEmpty {
                Text(summary)
                    .font(.nbSerif(15))
                    .foregroundStyle(NB.primary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .nbCard()
            } else if !transcriber.isTranscribing && !summarizer.isSummarizing {
                Text("No summary yet. Transcribe and summarize to generate one.")
                    .font(.nbSerif(14))
                    .foregroundStyle(NB.ghost)
                    .padding(20)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Re-summarize")
                    .font(.nbSerif(15, weight: .semibold))
                    .foregroundStyle(NB.primary)

                Picker("Type", selection: $resummarizeType) {
                    ForEach(MeetingType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .tint(NB.accent)

                TextField("Or enter a custom prompt...", text: $customPrompt, axis: .vertical)
                    .font(.nbSerif(14))
                    .foregroundStyle(NB.primary)
                    .padding(12)
                    .background(NB.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .lineLimit(3...6)

                Button {
                    Task { await resummarize() }
                } label: {
                    Text("Re-summarize")
                        .nbPill()
                }
                .buttonStyle(.plain)
                .disabled(meeting.transcript == nil || summarizer.isSummarizing)
            }
            .padding(20)
            .nbCard()
        }
        .padding(20)
    }

    private var transcriptTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let transcript = meeting.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.nbMono(12))
                    .foregroundStyle(NB.secondary)
                    .textSelection(.enabled)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .nbCard()
            } else {
                VStack(spacing: 12) {
                    Text("No transcript yet.")
                        .font(.nbSerif(15))
                        .foregroundStyle(NB.ghost)

                    if meeting.audioFileURL != nil {
                        Button {
                            Task { await transcribe() }
                        } label: {
                            Text("Transcribe Now")
                                .nbPill()
                        }
                        .buttonStyle(.plain)
                        .disabled(transcriber.isTranscribing)
                    }
                }
                .padding(20)
            }
        }
        .padding(20)
    }

    private var notesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let notes = meeting.markdownNotes, !notes.isEmpty {
                Text(notes)
                    .font(.nbSerif(14))
                    .foregroundStyle(NB.primary)
                    .textSelection(.enabled)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .nbCard()
            } else if meeting.summary != nil {
                Text("Export to Obsidian to generate the full note.")
                    .font(.nbSerif(14))
                    .foregroundStyle(NB.ghost)
                    .padding(20)
            } else {
                Text("Generate a summary first to create exportable notes.")
                    .font(.nbSerif(14))
                    .foregroundStyle(NB.ghost)
                    .padding(20)
            }
        }
        .padding(20)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await exportToObsidian() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.doc")
                    Text("Export")
                }
                .nbPill()
            }
            .buttonStyle(.plain)
            .disabled(meeting.summary == nil)

            Spacer()

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(NB.error)
                    .padding(12)
                    .background(NB.error.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(NB.surface)
    }

    private func autoProcess() async {
        guard meeting.transcript == nil,
              meeting.audioFileURL != nil,
              !transcriber.isTranscribing else { return }

        await transcribe()
    }

    private func transcribe() async {
        guard let audioURL = meeting.audioFileFullURL else { return }
        meeting.statusEnum = .transcribing

        do {
            let result = try await transcriber.transcribe(audioURL: audioURL)
            meeting.transcript = result.text
            meeting.statusEnum = autoSummarize ? .summarizing : .complete

            if autoSummarize {
                await summarizeTranscript()
            }
        } catch {
            meeting.statusEnum = .failed
            errorMessage = error.localizedDescription
        }
    }

    private func summarizeTranscript() async {
        guard let transcript = meeting.transcript else { return }
        meeting.statusEnum = .summarizing

        do {
            let summary = try await summarizer.summarize(
                transcript: transcript,
                meetingType: meeting.meetingTypeEnum
            )
            meeting.summary = summary
            meeting.statusEnum = .complete
        } catch {
            meeting.statusEnum = .failed
            errorMessage = error.localizedDescription
        }
    }

    private func resummarize() async {
        guard let transcript = meeting.transcript else { return }
        do {
            let prompt = customPrompt.isEmpty ? nil : customPrompt
            let summary = try await summarizer.summarize(
                transcript: transcript,
                meetingType: resummarizeType,
                customPrompt: prompt
            )
            meeting.summary = summary
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportToObsidian() async {
        do {
            try ObsidianExporter.export(meeting: meeting)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
