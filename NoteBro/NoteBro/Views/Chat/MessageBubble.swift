import SwiftUI

struct MessageBubble: View {
    let role: String
    let content: String
    var onApply: (() -> Void)?

    private var isUser: Bool { role == "user" }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            Text(isUser ? "You" : "NoteBro")
                .font(.nbMono(11))
                .foregroundStyle(NB.ghost)

            Text(content)
                .font(.nbSerif(15))
                .foregroundStyle(isUser ? NB.primary : NB.secondary)
                .textSelection(.enabled)
                .padding(14)
                .background(isUser ? NB.surface2 : NB.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !isUser && hasStructuredContent, let onApply {
                Button {
                    onApply()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                        Text("Apply to Notes")
                    }
                    .font(.nbSerif(12, weight: .medium))
                    .foregroundStyle(NB.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(NB.accentDim)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var hasStructuredContent: Bool {
        content.contains("## Summary") || content.contains("## Action Items") || content.contains("## Key Takeaways")
    }
}
