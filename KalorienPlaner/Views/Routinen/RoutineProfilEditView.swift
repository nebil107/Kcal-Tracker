import SwiftUI
import SwiftData

// Zeit-Helfer als freie Funktionen (nutzbar auch in Property-Defaults).
private func uhrzeitAlsDate(_ stunde: Int, _ minute: Int) -> Date {
    Calendar.current.date(bySettingHour: stunde, minute: minute, second: 0, of: Date()) ?? Date()
}
private func dateAlsKomponenten(_ d: Date) -> (Int, Int) {
    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
    return (c.hour ?? 0, c.minute ?? 0)
}

/// Anlegen/Bearbeiten eines Routine-Profils inkl. Essens-Slots (Zeit, Gewichtung, Kochen, Shake).
struct RoutineProfilEditView: View {
    let profil: RoutineProfil?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var alleProfile: [RoutineProfil]
    @Query private var settingsListe: [AppSettings]

    @State private var name = ""
    @State private var aktiv = false
    @State private var aufwachZeit = uhrzeitAlsDate(7, 0)
    @State private var cutoffZeit = uhrzeitAlsDate(21, 0)
    @State private var slots: [SlotDraft] = []
    @State private var geladen = false

    /// Editierbare Slot-Repräsentation (Zeit als Date für den DatePicker).
    struct SlotDraft: Identifiable {
        var id = UUID()
        var zeit: Date
        var gewichtProzent: Double
        var kochenErlaubt: Bool
        var istShakeSlot: Bool
        var tageszeit: Tageszeit
    }

    private var gewichtSumme: Double { slots.reduce(0) { $0 + $1.gewichtProzent } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profil") {
                    TextField("Name (z. B. Arbeitstag)", text: $name)
                    Toggle("Als aktives Profil verwenden", isOn: $aktiv)
                }
                Section("Zeiten") {
                    DatePicker("Aufwachen", selection: $aufwachZeit, displayedComponents: .hourAndMinute)
                    DatePicker("Cutoff (letzte Mahlzeit)", selection: $cutoffZeit, displayedComponents: .hourAndMinute)
                }

                Section {
                    ForEach($slots) { $slot in
                        slotEditor($slot)
                    }
                    .onDelete { slots.remove(atOffsets: $0) }

                    Button { slotHinzufuegen() } label: { Label("Slot hinzufügen", systemImage: "plus") }
                } header: {
                    Text("Essens-Slots")
                } footer: {
                    Text("Summe der Gewichtung: \(Format.ganzzahl(gewichtSumme)) % (Richtwert 100 %).")
                        .foregroundStyle(abs(gewichtSumme - 100) < 0.5 ? .secondary : Theme.warnung)
                }
            }
            .navigationTitle(profil == nil ? "Neues Profil" : "Profil bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }.disabled(name.isEmpty)
                }
            }
            .onAppear { if !geladen { laden(); geladen = true } }
        }
    }

    private func slotEditor(_ slot: Binding<SlotDraft>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker("Zeit", selection: slot.zeit, displayedComponents: .hourAndMinute)
            HStack {
                Text("Anteil")
                Spacer()
                TextField("%", value: slot.gewichtProzent, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60)
                Text("%").foregroundStyle(.secondary)
            }
            Picker("Tageszeit", selection: slot.tageszeit) {
                ForEach(Tageszeit.allCases) { Text($0.anzeige).tag($0) }
            }
            Toggle("Kochen erlaubt", isOn: slot.kochenErlaubt)
            Toggle("Shake-Slot", isOn: slot.istShakeSlot)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Aktionen

    private func slotHinzufuegen() {
        slots.append(SlotDraft(zeit: uhrzeitAlsDate(12, 0), gewichtProzent: 20,
                               kochenErlaubt: true, istShakeSlot: false, tageszeit: .egal))
    }

    private func laden() {
        guard let p = profil else { return }
        name = p.name; aktiv = p.aktiv
        aufwachZeit = uhrzeitAlsDate(p.aufwachStunde, p.aufwachMinute)
        cutoffZeit = uhrzeitAlsDate(p.cutoffStunde, p.cutoffMinute)
        slots = p.slots
            .sorted { $0.uhrzeit < $1.uhrzeit }
            .map { SlotDraft(id: $0.id, zeit: uhrzeitAlsDate($0.stunde, $0.minute),
                             gewichtProzent: $0.gewichtProzent, kochenErlaubt: $0.kochenErlaubt,
                             istShakeSlot: $0.istShakeSlot, tageszeit: $0.tageszeit) }
    }

    private func speichern() {
        let ziel = profil ?? RoutineProfil()
        ziel.name = name
        let (aufwachH, aufwachM) = dateAlsKomponenten(aufwachZeit)
        let (cutoffH, cutoffM) = dateAlsKomponenten(cutoffZeit)
        ziel.aufwachStunde = aufwachH; ziel.aufwachMinute = aufwachM
        ziel.cutoffStunde = cutoffH; ziel.cutoffMinute = cutoffM
        ziel.slots = slots.map { d in
            let (h, m) = dateAlsKomponenten(d.zeit)
            return SlotVorlage(id: d.id, stunde: h, minute: m, gewichtProzent: d.gewichtProzent,
                               kochenErlaubt: d.kochenErlaubt, istShakeSlot: d.istShakeSlot, tageszeit: d.tageszeit)
        }
        .sorted { $0.uhrzeit < $1.uhrzeit }
        ziel.aktiv = aktiv

        if profil == nil { context.insert(ziel) }

        // Exklusiv aktiv: alle anderen deaktivieren.
        if aktiv {
            for p in alleProfile where p.id != ziel.id { p.aktiv = false }
        }
        try? context.save()

        // Falls aktiv & Slot-Erinnerungen an: neu planen.
        if aktiv, settingsListe.first?.benachrichtigungenAktiv == true {
            NotificationManager.shared.slotErinnerungenPlanen(profil: ziel)
        }
        dismiss()
    }
}
