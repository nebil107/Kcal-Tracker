import SwiftUI

/// Drei Makro-Balken (Protein/Fett/Kohlenhydrate) mit Zielwerten.
struct MacroBarsView: View {
    let makros: Makros
    let ziel: Makros

    var body: some View {
        VStack(spacing: 14) {
            balken("Protein", wert: makros.protein, ziel: ziel.protein, farbe: Theme.protein)
            balken("Fett", wert: makros.fett, ziel: ziel.fett, farbe: Theme.fett)
            balken("Kohlenhydrate", wert: makros.kohlenhydrate, ziel: ziel.kohlenhydrate, farbe: Theme.kohlenhydrate)
        }
    }

    private func balken(_ name: String, wert: Double, ziel: Double, farbe: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.subheadline.bold())
                Spacer()
                Text("\(Format.gramm(wert)) / \(Format.gramm(ziel))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.kartenHintergrund)
                    Capsule().fill(farbe)
                        .frame(width: geo.size.width * (ziel > 0 ? min(1.0, wert / ziel) : 0))
                }
            }
            .frame(height: 10)
        }
    }
}
