import SwiftUI
import SwiftData

struct MeetingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.date, order: .reverse) private var meetings: [Meeting]
    @State private var searchText = ""

    private var filteredMeetings: [Meeting] {
        if searchText.isEmpty { return meetings }
        return meetings.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if filteredMeetings.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredMeetings) { meeting in
                            NavigationLink(value: meeting) {
                                MeetingCard(meeting: meeting)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .background(NB.bg)
            .searchable(text: $searchText, prompt: "Search meetings...")
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Meeting.self) { meeting in
                MeetingDetailView(meeting: meeting)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(NB.ghost)
            Text("No meetings yet")
                .font(.nbSerif(22, weight: .semibold))
                .foregroundStyle(NB.primary)
            Text("Record or import a meeting to get started.")
                .font(.nbSerif(15))
                .foregroundStyle(NB.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

struct MeetingCard: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.name)
                        .font(.nbSerif(16, weight: .semibold))
                        .foregroundStyle(NB.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(meeting.formattedDate)
                            .font(.nbMono(11))
                            .foregroundStyle(NB.secondary)
                        Text("·")
                            .foregroundStyle(NB.ghost)
                        Text(meeting.formattedDuration)
                            .font(.nbMono(11))
                            .foregroundStyle(NB.secondary)
                    }
                }

                Spacer()

                statusDot
            }

            HStack(spacing: 8) {
                Text(meeting.meetingTypeEnum.displayName)
                    .font(.nbSerif(11, weight: .medium))
                    .foregroundStyle(NB.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(NB.accentDim)
                    .clipShape(Capsule())

                if meeting.obsidianExported {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(NB.success)
                }
            }

            if let summary = meeting.summary, !summary.isEmpty {
                Text(summary)
                    .font(.nbSerif(13))
                    .foregroundStyle(NB.ghost)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .nbCard()
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch meeting.statusEnum {
        case .complete: NB.accent
        case .failed: NB.error
        case .recording, .importing, .transcribing, .summarizing: NB.warn
        }
    }
}
