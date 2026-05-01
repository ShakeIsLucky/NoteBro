import SwiftUI
import SwiftData

struct AgentChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.date, order: .reverse) private var meetings: [Meeting]
    @State private var agent = AgentService()
    @State private var inputText = ""
    @State private var selectedMeeting: Meeting?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                meetingPicker
                messageList
                inputBar
            }
            .background(NB.bg)
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.large)
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

    private var meetingPicker: some View {
        HStack {
            Menu {
                Button("All Meetings") {
                    selectedMeeting = nil
                    agent.clearHistory()
                }
                Divider()
                ForEach(meetings) { meeting in
                    Button(meeting.name) {
                        selectedMeeting = meeting
                        agent.clearHistory()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedMeeting != nil ? "doc.text" : "tray.full")
                        .font(.system(size: 14))
                    Text(selectedMeeting?.name ?? "All Meetings")
                        .font(.nbSerif(14, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(NB.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(NB.accentDim)
                .clipShape(Capsule())
            }

            Spacer()

            if !agent.history.isEmpty {
                Button {
                    agent.clearHistory()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                        .foregroundStyle(NB.ghost)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(NB.surface)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if agent.history.isEmpty {
                    emptyChat
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(agent.history.enumerated()), id: \.offset) { index, message in
                            MessageBubble(
                                role: message.role,
                                content: message.content
                            ) {
                                applyToMeeting(content: message.content)
                            }
                            .id(index)
                        }

                        if agent.isProcessing {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(NB.accent)
                                        .frame(width: 6, height: 6)
                                        .opacity(0.4)
                                        .animation(
                                            .easeInOut(duration: 0.6)
                                                .repeatForever()
                                                .delay(Double(i) * 0.2),
                                            value: agent.isProcessing
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                            .id("loading")
                        }
                    }
                    .padding(20)
                }
            }
            .onChange(of: agent.history.count) {
                withAnimation {
                    proxy.scrollTo(agent.history.count - 1, anchor: .bottom)
                }
            }
        }
    }

    private var emptyChat: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(NB.ghost)

            Text("Ask about your meetings")
                .font(.nbSerif(20, weight: .semibold))
                .foregroundStyle(NB.primary)

            VStack(spacing: 8) {
                suggestionChip("What were the action items?")
                suggestionChip("Summarize the key decisions")
                suggestionChip("Find meetings about pricing")
            }
        }
        .padding(40)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            inputText = text
            Task { await sendMessage() }
        } label: {
            Text(text)
                .font(.nbSerif(13))
                .foregroundStyle(NB.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(NB.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your meetings...", text: $inputText, axis: .vertical)
                .font(.nbSerif(15))
                .foregroundStyle(NB.primary)
                .padding(12)
                .background(NB.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .lineLimit(1...4)
                .onSubmit { Task { await sendMessage() } }

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(inputText.isEmpty ? NB.ghost : NB.bg)
                    .frame(width: 36, height: 36)
                    .background(inputText.isEmpty ? NB.surface : NB.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || agent.isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(NB.surface)
    }

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        do {
            _ = try await agent.sendMessage(text, meeting: selectedMeeting, allMeetings: meetings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyToMeeting(content: String) {
        guard let meeting = selectedMeeting else { return }
        meeting.summary = content
    }
}
