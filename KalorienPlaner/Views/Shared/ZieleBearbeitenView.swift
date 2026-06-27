import SwiftUI
import SwiftData

/// Editor für alle Tagesziele – aufrufbar vom Dashboard und aus den Einstellungen.
/// Makros entweder automatisch aus kcal (per Prozent) oder manuell in Gramm.
struct ZieleBearbeitenView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Kalorienziel") {
                    zahlZeile("kcal pro Tag", wert: $settings.kcalZiel)
                }

                Section {
                    Toggle("Makros automatisch aus kcal", isOn: $settings.makrosAutomatisch)
                    if settings.makrosAutomatisch {
                        prozentZeile("Protein", wert: $settings.proteinProzent)
                        prozentZeile("Fett", wert: $settings.fettProzent)
                        prozentZeile("Kohlenhydrate", wert: $settings.khProzent)
                        LabeledContent("Vorschau") {
                            Text("\(Format.gramm(vorschauProtein)) · \(Format.gramm(vorschauFett)) · \(Format.gramm(vorschauKh))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        zahlZeile("Protein (g)", wert: $settings.zielProtein_g)
                        zahlZeile("Fett (g)", wert: $settings.zielFett_g)
                        zahlZeile("Kohlenhydrate (g)", wert: $settings.zielKohlenhydrate_g)
                    }
                } header: {
                    Text("Makro-Ziele")
                } footer: {
                    Text("Atwater-Faktoren: 4 kcal/g Protein & Kohlenhydrate, 9 kcal/g Fett.")
                }

                Section("Wasser") {
                    zahlZeile("Ziel (ml)", wert: $settings.wasserZiel_ml)
                }
            }
            .navigationTitle("Ziele anpassen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { speichern() } }
            }
        }
    }

    // Vorschau der Gramm-Werte bei automatischem Modus.
    private var vorschauProtein: Double { settings.kcalZiel * settings.proteinProzent / 4 }
    private var vorschauFett: Double { settings.kcalZiel * settings.fettProzent / 9 }
    private var vorschauKh: Double { settings.kcalZiel * settings.khProzent / 4 }

    private func speichern() {
        if settings.makrosAutomatisch { settings.makrosAusKcalNeuBerechnen() }
        try? context.save()
        dismiss()
    }

    private func zahlZeile(_ titel: String, wert: Binding<Double>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField(titel, value: wert, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
        }
    }

    private func prozentZeile(_ titel: String, wert: Binding<Double>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField(titel, value: Binding(
                get: { wert.wrappedValue * 100 },
                set: { wert.wrappedValue = $0 / 100 }), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text("%").foregroundStyle(.secondary)
        }
    }
}
