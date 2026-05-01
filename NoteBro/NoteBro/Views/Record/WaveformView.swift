import SwiftUI

struct WaveformView: View {
    var currentPower: Float
    var isActive: Bool = true

    @State private var samples: [Float] = Array(repeating: 0, count: 70)

    var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 3
            let gap: CGFloat = 2
            let totalBarWidth = barWidth + gap
            let barCount = Int(size.width / totalBarWidth)
            let midY = size.height / 2

            for i in 0..<min(barCount, samples.count) {
                let amplitude = CGFloat(samples[i])
                let barHeight = max(3, amplitude * size.height * 0.8)
                let x = CGFloat(i) * totalBarWidth
                let rect = CGRect(
                    x: x,
                    y: midY - barHeight / 2,
                    width: barWidth,
                    height: barHeight
                )
                let opacity = 0.3 + amplitude * 0.7
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 1.5),
                    with: .color(NB.accent.opacity(opacity))
                )
            }
        }
        .frame(height: 120)
        .padding(16)
        .nbCard()
        .onChange(of: currentPower) {
            guard isActive else { return }
            samples.removeFirst()
            samples.append(currentPower)
        }
    }
}
