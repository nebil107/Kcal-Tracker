import SwiftUI

/// Wasser-Fortschritt (ml/L) mit Schnell-Buttons.
struct WasserView: View {
    let getrunken: Double
    let ziel: Double
    let hinzufuegen: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Wasser", systemImage: "drop.fill").font(.headline).foregroundStyle(Theme.wasser)
                Spacer()
                Text("\(Format.liter(ausMilliliter: getrunken)) / \(Format.liter(ausMilliliter: ziel))")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: ziel > 0 ? min(1.0, getrunken / ziel) : 0)
                .tint(Theme.wasser)
            HStack {
                Button { hinzufuegen(250) } label: { Text("+250 ml") }
                Button { hinzufuegen(500) } label: { Text("+500 ml") }
                Spacer()
            }
            .buttonStyle(.bordered)
            .tint(Theme.wasser)
        }
    }
}
