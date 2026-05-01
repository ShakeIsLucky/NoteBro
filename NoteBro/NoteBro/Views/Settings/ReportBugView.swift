import SwiftUI

struct ReportBugView: View {
    @Environment(\.openURL) private var openURL
    @State private var issueText = ""
    @State private var showMissingTextAlert = false

    private let issuesURL = URL(string: "https://github.com/ShakeIsLucky/NoteBro/issues/new")!

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Report a Bug")
                .font(.nbSerif(32, weight: .bold))
                .foregroundStyle(NB.primary)

            Text("Tell us what broke, what you expected, and any steps to reproduce it. Your report will open as a pre-filled GitHub issue.")
                .font(.nbSerif(15))
                .foregroundStyle(NB.secondary)

            TextEditor(text: $issueText)
                .font(.nbSerif(16))
                .foregroundStyle(NB.primary)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 260)
                .background(NB.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if issueText.isEmpty {
                        Text("Describe the issue...")
                            .font(.nbSerif(16))
                            .foregroundStyle(NB.ghost)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            Button {
                submitIssue()
            } label: {
                HStack {
                    Image(systemName: "ladybug.fill")
                    Text("Open GitHub Issue")
                }
                .frame(maxWidth: .infinity)
                .nbPill(filled: true)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
        .background(NB.bg)
        .navigationTitle("Report Bug")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Add a description", isPresented: $showMissingTextAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please describe the bug before opening a GitHub issue.")
        }
    }

    private func submitIssue() {
        let trimmed = issueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showMissingTextAlert = true
            return
        }

        var components = URLComponents(url: issuesURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "title", value: issueTitle(from: trimmed)),
            URLQueryItem(name: "body", value: issueBody(from: trimmed)),
            URLQueryItem(name: "labels", value: "bug")
        ]

        if let url = components.url {
            openURL(url)
        }
    }

    private func issueTitle(from text: String) -> String {
        let firstLine = text.components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if firstLine.isEmpty {
            return "Bug report"
        }

        return firstLine.count > 80 ? String(firstLine.prefix(77)) + "..." : firstLine
    }

    private func issueBody(from text: String) -> String {
        """
        ## Bug Report

        \(text)

        ---
        Reported from the NoteBro app.
        """
    }
}
