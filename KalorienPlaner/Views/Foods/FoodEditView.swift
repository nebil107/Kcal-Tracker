import SwiftUI
import SwiftData

/// Anlegen/Bearbeiten eines Lebensmittels. Alle Felder sind editierbar (nichts hartkodiert).
struct FoodEditView: View {
    /// nil = neues Lebensmittel anlegen.
    let food: Food?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.kategorie) private var alleFoods: [Food]

    @State private var name = ""
    @State private var kategorie = ""
    @State private var istFestePortion = false

    // Variabel (je 100 g)
    @State private var kcalPro100g = 0.0
    @State private var proteinPro100g = 0.0
    @State private var fettPro100g = 0.0
    @State private var khPro100g = 0.0

    // Feste Portion
    @State private var festeKcal = 0.0
    @State private var festeProtein = 0.0
    @State private var festeFett = 0.0
    @State private var festeKh = 0.0
    @State private var portionsName = "Portion"

    @State private var standardPortion = 100.0
    @State private var magScore = 50.0
    @State private var nieVorschlagen = false
    @State private var shakeTauglich = false
    @State private var kochAufwand: KochAufwand = .keiner
    @State private var tageszeiten: Set<Tageszeit> = [.egal]
    @State private var tagsText = ""

    @State private var geladen = false

    private var kategorienVorschlaege: [String] {
        Array(Set(alleFoods.map(\.kategorie).filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Allgemein") {
                    TextField("Name", text: $name)
                    TextField("Kategorie", text: $kategorie)
                    if !kategorienVorschlaege.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(kategorienVorschlaege, id: \.self) { k in
                                    Button(k) { kategorie = k }
                                        .font(.caption)
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    Toggle("Feste Portion (keine Gramm-Rechnung)", isOn: $istFestePortion)
                }

                if istFestePortion {
                    Section("Werte je Portion") {
                        TextField("Portionsname (z. B. Riegel)", text: $portionsName)
                        zahl("kcal", $festeKcal)
                        zahl("Protein (g)", $festeProtein)
                        zahl("Fett (g)", $festeFett)
                        zahl("Kohlenhydrate (g)", $festeKh)
                    }
                } else {
                    Section("Nährwerte je 100 g") {
                        zahl("kcal", $kcalPro100g)
                        zahl("Protein (g)", $proteinPro100g)
                        zahl("Fett (g)", $fettPro100g)
                        zahl("Kohlenhydrate (g)", $khPro100g)
                    }
                }

                Section("Standard & Planung") {
                    zahl(istFestePortion ? "Referenzgewicht (g)" : "Standardportion (g)", $standardPortion)
                    VStack(alignment: .leading) {
                        Text("Beliebtheit (magScore): \(Format.ganzzahl(magScore))")
                        Slider(value: $magScore, in: 0...100, step: 1)
                    }
                    Toggle("Nie vorschlagen", isOn: $nieVorschlagen)
                    Toggle("Shake-tauglich", isOn: $shakeTauglich)
                    Picker("Kochaufwand", selection: $kochAufwand) {
                        ForEach(KochAufwand.allCases) { Text($0.anzeige).tag($0) }
                    }
                }

                Section("Passende Tageszeiten") {
                    ForEach(Tageszeit.allCases) { tz in
                        Toggle(tz.anzeige, isOn: Binding(
                            get: { tageszeiten.contains(tz) },
                            set: { an in
                                if an { tageszeiten.insert(tz) } else { tageszeiten.remove(tz) }
                            }))
                    }
                }

                Section("Tags (mit Komma getrennt)") {
                    TextField("z. B. günstig, schnell", text: $tagsText)
                }

                if food != nil {
                    Section {
                        Button(role: .destructive) { loeschen() } label: {
                            Label("Lebensmittel löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(food == nil ? "Neues Lebensmittel" : "Bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }.disabled(name.isEmpty)
                }
            }
            .onAppear { if !geladen { laden(); geladen = true } }
        }
    }

    private func zahl(_ titel: String, _ wert: Binding<Double>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField(titel, value: wert, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
        }
    }

    private func laden() {
        guard let f = food else { return }
        name = f.name; kategorie = f.kategorie; istFestePortion = f.istFestePortion
        kcalPro100g = f.kcalPro100g; proteinPro100g = f.proteinPro100g
        fettPro100g = f.fettPro100g; khPro100g = f.kohlenhydratePro100g
        festeKcal = f.festeKcal; festeProtein = f.festeProtein; festeFett = f.festeFett; festeKh = f.festeKohlenhydrate
        portionsName = f.portionsName; standardPortion = f.standardPortion_g
        magScore = f.magScore; nieVorschlagen = f.nieVorschlagen; shakeTauglich = f.shakeTauglich
        kochAufwand = f.kochAufwand; tageszeiten = Set(f.tageszeiten)
        tagsText = f.tags.joined(separator: ", ")
    }

    private func speichern() {
        let ziel = food ?? Food()
        ziel.name = name
        ziel.kategorie = kategorie.isEmpty ? "Allgemein" : kategorie
        ziel.istFestePortion = istFestePortion
        ziel.kcalPro100g = kcalPro100g; ziel.proteinPro100g = proteinPro100g
        ziel.fettPro100g = fettPro100g; ziel.kohlenhydratePro100g = khPro100g
        ziel.festeKcal = festeKcal; ziel.festeProtein = festeProtein
        ziel.festeFett = festeFett; ziel.festeKohlenhydrate = festeKh
        ziel.portionsName = portionsName.isEmpty ? "Portion" : portionsName
        ziel.standardPortion_g = standardPortion
        ziel.magScore = magScore; ziel.nieVorschlagen = nieVorschlagen; ziel.shakeTauglich = shakeTauglich
        ziel.kochAufwand = kochAufwand
        ziel.tageszeiten = tageszeiten.isEmpty ? [.egal] : Array(tageszeiten)
        ziel.tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if food == nil { context.insert(ziel) }
        try? context.save()
        dismiss()
    }

    private func loeschen() {
        if let f = food { context.delete(f); try? context.save() }
        dismiss()
    }
}
