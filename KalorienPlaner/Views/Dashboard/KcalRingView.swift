import SwiftUI

/// Großer Kalorien-Ring (gegessen / Ziel) mit Restanzeige.
struct KcalRingView: View {
    let gegessen: Double
    let ziel: Double

    private var anteil: Double { ziel > 0 ? min(1.0, gegessen / ziel) : 0 }
    private var verbleibend: Double { max(0, ziel - gegessen) }
    private var ueberschritten: Bool { gegessen > ziel && ziel > 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.kartenHintergrund, lineWidth: 18)
            Circle()
                .trim(from: 0, to: anteil)
                .stroke(ueberschritten ? Theme.warnung : Theme.akzent,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: anteil)

            VStack(spacing: 4) {
                Text(Format.ganzzahl(gegessen))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("von \(Format.kcal(ziel))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(ueberschritten ? "\(Format.kcal(gegessen - ziel)) drüber" : "noch \(Format.kcal(verbleibend))")
                    .font(.caption.bold())
                    .foregroundStyle(ueberschritten ? Theme.warnung : Theme.akzent)
            }
        }
        .frame(width: 220, height: 220)
        .padding(.vertical, Theme.Abstand.mittel)
    }
}
