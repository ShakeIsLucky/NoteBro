import Foundation

enum MeetingType: String, Codable, CaseIterable {
    case automatic
    case oneOnOne
    case standup
    case brainstorm
    case interview
    case salesCall
    case investorMeeting

    var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .oneOnOne: "1:1"
        case .standup: "Standup"
        case .brainstorm: "Brainstorm"
        case .interview: "Interview"
        case .salesCall: "Sales Call"
        case .investorMeeting: "Investor Meeting"
        }
    }

    var icon: String {
        switch self {
        case .automatic: "wand.and.stars"
        case .oneOnOne: "person.2"
        case .standup: "figure.stand"
        case .brainstorm: "brain.head.profile"
        case .interview: "questionmark.bubble"
        case .salesCall: "phone.arrow.up.right"
        case .investorMeeting: "chart.line.uptrend.xyaxis"
        }
    }

    var promptTemplate: String {
        switch self {
        case .automatic:
            """
            Summarize this meeting transcript. Extract:
            1. **Key Takeaways** — the most important points discussed
            2. **Decisions Made** — any concrete decisions reached
            3. **Action Items** — tasks assigned, with owners if mentioned
            4. **Participants** — names of people who spoke
            5. **Open Questions** — anything left unresolved

            Format in Markdown with clear sections. Be concise but thorough.
            """
        case .oneOnOne:
            """
            Summarize this 1:1 meeting transcript. Extract:
            1. **Updates** — what each person shared about their work
            2. **Feedback** — any feedback given or received
            3. **Blockers** — issues raised that need resolution
            4. **Action Items** — tasks and commitments made
            5. **Personal Notes** — career goals, morale, or personal topics discussed

            Format in Markdown. Keep the tone supportive and constructive.
            """
        case .standup:
            """
            Summarize this standup meeting transcript. For each participant, extract:
            1. **Completed** — what they finished since last standup
            2. **In Progress** — what they're working on now
            3. **Blockers** — anything preventing progress

            Also note any cross-team dependencies or escalations. Format in Markdown.
            """
        case .brainstorm:
            """
            Summarize this brainstorming session. Extract:
            1. **Ideas Generated** — all ideas proposed, grouped by theme
            2. **Top Ideas** — which ideas had the most energy or support
            3. **Concerns Raised** — pushback or risks identified
            4. **Next Steps** — what was decided for follow-up
            5. **Parking Lot** — ideas tabled for later

            Format in Markdown. Preserve the creative intent of each idea.
            """
        case .interview:
            """
            Summarize this interview transcript. Extract:
            1. **Candidate Background** — relevant experience and skills discussed
            2. **Key Questions & Answers** — notable Q&A exchanges
            3. **Strengths** — positive signals from the conversation
            4. **Concerns** — potential red flags or gaps
            5. **Culture Fit Notes** — observations about team/culture alignment
            6. **Recommendation** — overall impression and suggested next steps

            Format in Markdown. Be objective and evidence-based.
            """
        case .salesCall:
            """
            Summarize this sales call transcript. Extract:
            1. **Prospect Info** — company, role, and context
            2. **Pain Points** — problems the prospect described
            3. **Interest Level** — how engaged they seemed
            4. **Objections** — concerns or pushback raised
            5. **Pricing Discussion** — any numbers or tiers discussed
            6. **Next Steps** — follow-up actions and timeline
            7. **Deal Stage** — where this stands in the pipeline

            Format in Markdown. Focus on actionable sales intelligence.
            """
        case .investorMeeting:
            """
            Summarize this investor meeting transcript. Extract:
            1. **Investor Background** — fund, check size, thesis if mentioned
            2. **Key Questions Asked** — what the investor wanted to know
            3. **Traction Discussed** — metrics, growth, or milestones shared
            4. **Valuation / Terms** — any financial terms discussed
            5. **Concerns Raised** — investor hesitations or risks flagged
            6. **Commitment / Interest** — level of interest expressed
            7. **Follow-Up Items** — materials to send, next meeting, intros requested

            Format in Markdown. Capture the investor's sentiment accurately.
            """
        }
    }
}

enum MeetingStatus: String, Codable {
    case recording
    case importing
    case transcribing
    case summarizing
    case complete
    case failed
}
