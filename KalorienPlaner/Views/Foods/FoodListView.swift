import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Liste aller Lebensmittel, gruppiert nach Kategorie, mit Suche, Bearbeitung und CSV-Import.
struct FoodListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Food.kategorie), SortDescriptor(\Food.name)]) private var foods: [Food]

    @State private var suche = ""
    @State private var zeigeNeu = false
    @State private var zeigeCSVImport = false
    @State private var importMeldung: String?
    @State private var zeigeImportMeldung = false
    @State private var csvExport: ExportDatei?

    /// Identifizierbarer Wrapper für die exportierte CSV-Datei (für `.sheet(item:)`).
    struct ExportDatei: Identifiable {
        let id = UUID()
        let url: URL
    }

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
                            NavigationLink {
                                FoodEditView(food: food)
                            } label: {
                                zeile(food)
                            }
                        }
                        .onDelete { indexSet in
                            loeschen(in: kategorie, indexSet: indexSet)
                        }
                    }
                }
            }
            .searchable(text: $suche, prompt: "Lebensmittel suchen")
            .navigationTitle("Lebensmittel")
            .overlay {
                if foods.isEmpty {
                    ContentUnavailableView("Keine Lebensmittel", systemImage: "fork.knife",
                                           description: Text("Lege dein erstes Lebensmittel an."))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { zeigeNeu = true } label: { Label("Neues Lebensmittel", systemImage: "plus") }
                        Button { zeigeCSVImport = true } label: { Label("Aus CSV importieren", systemImage: "tablecells") }
                        Button { exportiereCSV() } label: { Label("Als CSV exportieren", systemImage: "square.and.arrow.up") }
                            .disabled(foods.isEmpty)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $zeigeNeu) { FoodEditView(food: nil) }
            .fileImporter(isPresented: $zeigeCSVImport,
                          allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                csvImportieren(result)
            }
            .alert("CSV-Import", isPresented: $zeigeImportMeldung) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMeldung ?? "")
            }
            .sheet(item: $csvExport) { datei in
                NavigationStack {
                    VStack(spacing: Theme.Abstand.gross) {
                        Image(systemName: "tablecells").font(.system(size: 44)).foregroundStyle(Theme.akzent)
                        Text("CSV mit \(foods.count) Lebensmitteln ist bereit.")
                            .multilineTextAlignment(.center)
                        ShareLink(item: datei.url) {
                            Label("Teilen / Speichern", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("CSV exportieren")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Fertig") { csvExport = nil } }
                    }
                }
            }
        }
    }

    private func exportiereCSV() {
        let csv = CSVImport.exportiere(foods: foods)
        // BOM voranstellen, damit Excel die Umlaute korrekt als UTF-8 erkennt.
        let inhalt = "\u{FEFF}" + csv
        let name = "KalorienPlaner-Lebensmittel.csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try inhalt.data(using: .utf8)?.write(to: url, options: .atomic)
            csvExport = ExportDatei(url: url)
        } catch {
            importMeldung = "Export fehlgeschlagen: \(error.localizedDescription)"
            zeigeImportMeldung = true
        }
    }

    private func csvImportieren(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) ?? ""
                let erg = CSVImport.importiere(text: text, context: context)
                importMeldung = erg.zusammenfassung
            } catch {
                importMeldung = "Datei konnte nicht gelesen werden: \(error.localizedDescription)"
            }
        case .failure(let error):
            importMeldung = "Auswahl fehlgeschlagen: \(error.localizedDescription)"
        }
        zeigeImportMeldung = true
    }

    private func zeile(_ food: Food) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(food.name)
                Text(food.istFestePortion
                     ? "\(Format.kcal(food.festeKcal)) / \(food.portionsName)"
                     : "\(Format.kcal(food.kcalPro100g)) / 100 g")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if food.nieVorschlagen { Image(systemName: "nosign").foregroundStyle(.secondary) }
            if food.shakeTauglich { Image(systemName: "cup.and.saucer.fill").foregroundStyle(Theme.akzent) }
        }
    }

    private func loeschen(in kategorie: String, indexSet: IndexSet) {
        let inKategorie = gefiltert.filter { $0.kategorie == kategorie }
        for index in indexSet { context.delete(inKategorie[index]) }
        try? context.save()
    }
}
