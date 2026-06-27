import SwiftUI
import SwiftData

/// Eintragen eines Verzehrs mit automatischer Tara-/Netto- und Live-Nährwertberechnung.
struct LogEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppZustand.self) private var zustand

    @Query(sort: \Behaelter.name) private var behaelter: [Behaelter]

    @State private var food: Food?
    @State private var zeigePicker = false

    // Variable Eingabe
    @State private var bruttoWert: Double = 0
    @State private var einheit: Gewichtseinheit = .gramm
    @State private var gewaehlterBehaelter: Behaelter?

    // Feste Portion
    @State private var portionen: Double = 1

    var body: some View {
        NavigationStack {
            Form {
                lebensmittelSektion
                if let food {
                    if food.istFestePortion {
                        festePortionSektion(food)
                    } else {
                        gewichtSektion
                        behaelterSektion
                    }
                    ergebnisSektion(food)
                }
            }
            .navigationTitle("Eintragen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }.disabled(food == nil || werte.kcal <= 0)
                }
            }
            .sheet(isPresented: $zeigePicker) {
                FoodPickerView { gewaehlt in
                    food = gewaehlt
                    portionen = 1
                    bruttoWert = gewaehlt.standardPortion_g
                }
            }
            .onAppear(perform: vorbelegen)
        }
    }

    // MARK: - Sektionen

    private var lebensmittelSektion: some View {
        Section("Lebensmittel") {
            Button { zeigePicker = true } label: {
                HStack {
                    Text(food?.name ?? "Lebensmittel wählen")
                        .foregroundStyle(food == nil ? Color.accentColor : .primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var gewichtSektion: some View {
        Section("Menge") {
            HStack {
                TextField("Gewicht", value: $bruttoWert, format: .number)
                    .keyboardType(.decimalPad)
                Picker("Einheit", selection: $einheit) {
                    ForEach(Gewichtseinheit.allCases) { e in Text(e.anzeige).tag(e) }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            Text("Brutto (im Behälter gewogen)").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var behaelterSektion: some View {
        Section("Behälter (Tara)") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    behaelterChip(name: "Kein Behälter", aktiv: gewaehlterBehaelter == nil) {
                        gewaehlterBehaelter = nil
                    }
                    ForEach(behaelter) { b in
                        behaelterChip(name: "\(b.name) · \(Format.gramm(b.tara_g))", aktiv: gewaehlterBehaelter?.id == b.id) {
                            gewaehlterBehaelter = b
                        }
                    }
                }
            }
            LabeledContent("Tara", value: Format.gramm(tara))
            LabeledContent("Netto", value: Format.gramm(netto))
        }
    }

    private func festePortionSektion(_ food: Food) -> some View {
        Section("Portionen") {
            Stepper(value: $portionen, in: 0.5...20, step: 0.5) {
                Text("\(Format.dezimal(portionen, maxNachkomma: 1)) × \(food.portionsName)")
            }
        }
    }

    private func ergebnisSektion(_ food: Food) -> some View {
        Section("Ergebnis") {
            LabeledContent("Kalorien") { Text(Format.kcal(werte.kcal)).bold() }
            LabeledContent("Protein", value: Format.gramm(werte.protein))
            LabeledContent("Fett", value: Format.gramm(werte.fett))
            LabeledContent("Kohlenhydrate", value: Format.gramm(werte.kohlenhydrate))
        }
    }

    private func behaelterChip(name: String, aktiv: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Text(name)
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(aktiv ? Theme.akzent : Theme.kartenHintergrund)
                .foregroundStyle(aktiv ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Berechnung

    private var brutto_g: Double { NutritionCalculator.inGramm(bruttoWert, einheit: einheit) }
    private var tara: Double { gewaehlterBehaelter?.tara_g ?? 0 }
    private var netto: Double { NutritionCalculator.netto_g(brutto_g: brutto_g, tara_g: tara) }

    private var werte: Naehrwerte {
        guard let food else { return .null }
        return food.istFestePortion ? food.naehrwerteFest(portionen: portionen) : food.naehrwerte(netto_g: netto)
    }

    // MARK: - Aktionen

    private func vorbelegen() {
        guard food == nil, let id = zustand.eingabeVorbelegtFoodID else { return }
        let pred = #Predicate<Food> { $0.id == id }
        if let f = (try? context.fetch(FetchDescriptor<Food>(predicate: pred)))?.first {
            food = f
            bruttoWert = f.standardPortion_g
            portionen = 1
        }
        zustand.eingabeVorbelegtFoodID = nil
    }

    private func speichern() {
        guard let food else { return }
        let w = werte
        let log = LogEntry(
            zeitstempel: Date(),
            foodName: food.name,
            bruttogewicht_g: food.istFestePortion ? 0 : brutto_g,
            tara_g: food.istFestePortion ? 0 : tara,
            netto_g: food.istFestePortion ? 0 : netto,
            istFestePortion: food.istFestePortion,
            portionen: food.istFestePortion ? portionen : 0,
            kcal: w.kcal, protein: w.protein, fett: w.fett, kohlenhydrate: w.kohlenhydrate,
            tageszeit: Tageszeit.ausUhrzeit(Uhrzeit.aus(date: Date())))
        log.food = food
        log.behaelter = food.istFestePortion ? nil : gewaehlterBehaelter
        context.insert(log)
        try? context.save()
        dismiss()
    }
}
