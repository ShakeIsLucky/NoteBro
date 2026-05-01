import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = AudioRecorder()
    @State private var meetingName = ""
    @State private var selectedType: MeetingType = .automatic
    @State private var showImporter = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    meetingNameField

                    meetingTypePicker

                    WaveformView(
                        currentPower: recorder.currentPower,
                        isActive: recorder.isRecording
                    )

                    timerDisplay

                    recordControls

                    importButton
                }
                .padding(24)
            }
            .background(NB.bg)
            .navigationTitle("")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: AudioImporter.supportedTypes,
                allowsMultipleSelection: true
            ) { result in
                Task { await handleImport(result) }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        Text("Record")
            .font(.nbSerif(32, weight: .bold))
            .foregroundStyle(NB.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var meetingNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meeting Name")
                .font(.nbSerif(13, weight: .semibold))
                .foregroundStyle(NB.secondary)
            TextField("Morning standup...", text: $meetingName)
                .font(.nbSerif(17))
                .foregroundStyle(NB.primary)
                .padding(14)
                .background(NB.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var meetingTypePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meeting Type")
                .font(.nbSerif(13, weight: .semibold))
                .foregroundStyle(NB.secondary)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(MeetingType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedType = type
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18))
                            Text(type.displayName)
                                .font(.nbSerif(11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(selectedType == type ? NB.bg : NB.secondary)
                        .background(selectedType == type ? NB.accent : NB.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var timerDisplay: some View {
        Text(formatTime(recorder.elapsedTime))
            .font(.nbSerif(48, weight: .light))
            .foregroundStyle(recorder.isRecording ? NB.primary : NB.ghost)
            .monospacedDigit()
    }

    private var recordControls: some View {
        HStack(spacing: 32) {
            if recorder.isRecording {
                Button {
                    if recorder.isPaused {
                        recorder.resumeRecording()
                    } else {
                        recorder.pauseRecording()
                    }
                } label: {
                    Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(NB.secondary)
                        .frame(width: 56, height: 56)
                        .background(NB.surface)
                        .clipShape(Circle())
                }

                Button {
                    stopAndSave()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(NB.error)
                        .clipShape(Circle())
                }
            } else {
                Button {
                    Task { await startRecording() }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(NB.bg)
                        .frame(width: 80, height: 80)
                        .background(NB.accent)
                        .clipShape(Circle())
                        .shadow(color: NB.accent.opacity(0.4), radius: 12, y: 4)
                }
            }
        }
    }

    private var importButton: some View {
        Button {
            showImporter = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                Text("Import Voice Memo")
            }
            .nbPill(filled: false)
        }
        .buttonStyle(.plain)
    }

    private func startRecording() async {
        do {
            try await recorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopAndSave() {
        guard let _ = recorder.stopRecording() else { return }
        let name = meetingName.isEmpty ? "Meeting \(Date().formatted(date: .abbreviated, time: .shortened))" : meetingName

        let meeting = Meeting(name: name, meetingType: selectedType, status: .complete)
        meeting.duration = recorder.elapsedTime
        meeting.audioFileURL = recorder.relativeRecordingPath
        modelContext.insert(meeting)

        meetingName = ""
        selectedType = .automatic
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            do {
                let imported = try await AudioImporter.importFiles(from: urls)
                for audio in imported {
                    let meeting = Meeting(
                        name: audio.originalName,
                        date: audio.creationDate,
                        meetingType: selectedType,
                        status: .complete
                    )
                    meeting.duration = audio.duration
                    meeting.audioFileURL = audio.relativePath
                    modelContext.insert(meeting)
                }
            } catch {
                errorMessage = "Failed to import: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "Import cancelled: \(error.localizedDescription)"
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}
