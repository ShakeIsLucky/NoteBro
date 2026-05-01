import SwiftUI

enum NB {
    // Deep forest backgrounds
    static let bg = Color(red: 0.04, green: 0.10, blue: 0.06)
    static let surface = Color(red: 0.07, green: 0.13, blue: 0.09)
    static let surface2 = Color(red: 0.10, green: 0.18, blue: 0.13)
    static let surface3 = Color(red: 0.14, green: 0.22, blue: 0.17)

    // Text
    static let primary = Color(red: 0.94, green: 0.99, blue: 0.96)
    static let secondary = Color(red: 0.53, green: 0.75, blue: 0.60)
    static let ghost = Color(red: 0.25, green: 0.40, blue: 0.30)

    // Accent — Cash App bright green
    static let accent = Color(red: 0.20, green: 0.83, blue: 0.46)
    static let accentDim = Color(red: 0.20, green: 0.83, blue: 0.46).opacity(0.12)

    // Semantic
    static let success = Color(red: 0.29, green: 0.87, blue: 0.50)
    static let error = Color(red: 0.95, green: 0.35, blue: 0.35)
    static let warn = Color(red: 0.95, green: 0.75, blue: 0.30)
}

extension Font {
    static func nbSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func nbMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static var nbSectionLabel: Font {
        .system(size: 13, weight: .semibold, design: .serif)
    }
}

struct NBCard: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(NB.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}

struct NBPillButton: ViewModifier {
    var filled: Bool = true

    func body(content: Content) -> some View {
        content
            .font(.nbSerif(15, weight: .semibold))
            .foregroundStyle(filled ? NB.bg : NB.accent)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(filled ? NB.accent : NB.accentDim)
            .clipShape(Capsule())
    }
}

extension View {
    func nbCard(radius: CGFloat = 16) -> some View {
        modifier(NBCard(radius: radius))
    }

    func nbPill(filled: Bool = true) -> some View {
        modifier(NBPillButton(filled: filled))
    }

    func nbSectionHeader() -> some View {
        self
            .font(.nbSectionLabel)
            .foregroundStyle(NB.secondary)
            .textCase(.uppercase)
    }
}
