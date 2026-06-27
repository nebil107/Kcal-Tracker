import SwiftUI

/// Zeigt die Zusammensetzung eines vorgeschlagenen Shakes. Überschreiben geschieht über
/// „Ablehnen" im Plan (neu zusammenstellen) bzw. durch Anpassen der Lebensmittel.
struct ShakeDetailView: View {
    let shake: ShakeVorschlag
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Zutaten") {
                    ForEach(shake.komponenten) { k in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(k.name)
                                Text(Format.gramm(k.menge_g)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Format.kcal(k.kcal)).font(.subheadline.bold())
                        }
                    }
                }
                Section("Summe") {
                    LabeledContent("Kalorien") { Text(Format.kcal(shake.gesamtKcal)).bold() }
                    LabeledContent("Protein", value: Format.gramm(shake.gesamtMakros.protein))
                    LabeledContent("Fett", value: Format.gramm(shake.gesamtMakros.fett))
                    LabeledContent("Kohlenhydrate", value: Format.gramm(shake.gesamtMakros.kohlenhydrate))
                }
            }
            .navigationTitle("Shake")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Schließen") { dismiss() } }
            }
        }
    }
}
