import SwiftUI
import SwiftData

/// Verwaltung der Behälter (Tara-Gewichte). Frei anlegbar/änderbar/löschbar.
struct BehaelterListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Behaelter.name) private var behaelter: [Behaelter]

    @State private var bearbeite: Behaelter?
    @State private var zeigeNeu = false

    var body: some View {
        List {
            ForEach(behaelter) { b in
                Button { bearbeite = b } label: {
                    HStack {
                        Text(b.name).foregroundStyle(.primary)
                        Spacer()
                        Text(Format.gramm(b.tara_g)).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                for i in indexSet { context.delete(behaelter[i]) }
                try? context.save()
            }
        }
        .navigationTitle("Behälter")
        .overlay {
            if behaelter.isEmpty {
                ContentUnavailableView("Keine Behälter", systemImage: "takeoutbag.and.cup.and.straw",
                    description: Text("Lege Schüsseln, Teller usw. mit ihrem Leergewicht an."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { zeigeNeu = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $bearbeite) { BehaelterEditView(behaelter: $0) }
        .sheet(isPresented: $zeigeNeu) { BehaelterEditView(behaelter: nil) }
    }
}

/// Anlegen/Bearbeiten eines Behälters.
struct BehaelterEditView: View {
    let behaelter: Behaelter?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var tara = 0.0
    @State private var geladen = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (z. B. Müslischüssel)", text: $name)
                HStack {
                    Text("Leergewicht (Tara)")
                    Spacer()
                    TextField("g", value: $tara, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                    Text("g").foregroundStyle(.secondary)
                }
            }
            .navigationTitle(behaelter == nil ? "Neuer Behälter" : "Behälter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }.disabled(name.isEmpty)
                }
            }
            .onAppear {
                if !geladen, let b = behaelter { name = b.name; tara = b.tara_g; geladen = true }
            }
        }
    }

    private func speichern() {
        let ziel = behaelter ?? Behaelter()
        ziel.name = name
        ziel.tara_g = tara
        if behaelter == nil { context.insert(ziel) }
        try? context.save()
        dismiss()
    }
}
