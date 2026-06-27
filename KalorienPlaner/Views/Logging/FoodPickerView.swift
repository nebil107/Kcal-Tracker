import SwiftUI
import SwiftData

/// Auswahl-Liste für Lebensmittel, gruppiert nach Kategorie, mit Suche.
struct FoodPickerView: View {
    let onAuswahl: (Food) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.name) private var foods: [Food]
    @State private var suche = ""
    @State private var zeigeNeu = false

    private var gefiltert: [Food] {
        guard !suche.isEmpty else { return foods }
        return foods.filter {
            $0.name.localizedCaseInsensitiveContains(suche) ||
            $0.kategorie.localizedCaseInsensitiveContains(suche)
        }
    }

    private var kategorien: [String] {
        Array(Set(gefiltert.map(\.kategorie))).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(kategorien, id: \.self) { kategorie in
                    Section(kategorie.isEmpty ? "Ohne Kategorie" : kategorie) {
                        ForEach(gefiltert.filter { $0.kategorie == kategorie }) { food in
                            Button {
                                onAuswahl(food)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(food.name).foregroundStyle(.primary)
                                        Text(naehrwertHinweis(food)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if food.shakeTauglich {
                                        Image(systemName: "cup.and.saucer.fill").foregroundStyle(Theme.akzent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $suche, prompt: "Suchen")
            .navigationTitle("Lebensmittel wählen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { zeigeNeu = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $zeigeNeu) { FoodEditView(food: nil) }
        }
    }

    private func naehrwertHinweis(_ f: Food) -> String {
        if f.istFestePortion {
            return "\(Format.kcal(f.festeKcal)) / \(f.portionsName)"
        }
        return "\(Format.kcal(f.kcalPro100g)) / 100 g"
    }
}
