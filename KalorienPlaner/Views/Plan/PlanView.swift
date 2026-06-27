import SwiftUI
import SwiftData

/// Der heutige Plan: Vorschläge je Slot mit Annehmen/Ablehnen und Wächter-Warnungen.
struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppZustand.self) private var zustand
    @Query private var settingsListe: [AppSettings]

    @State private var sitzung: PlanSitzung?
    @State private var angenommen: Set<UUID> = []
    @State private var zeigeEingabe = false
    @State private var shakeDetail: ShakeDetailWrap?

    private var settings: AppSettings? { settingsListe.first }

    var body: some View {
        NavigationStack {
            Group {
                if let sitzung {
                    inhalt(sitzung)
                } else {
                    ContentUnavailableView("Kein Plan",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Lege unter „Routinen" ein aktives Profil mit Essens-Slots an."))
                }
            }
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { neuPlanen() } label: { Label("Aktualisieren", systemImage: "arrow.clockwise") }
                }
            }
            .onAppear { if sitzung == nil { neuPlanen() } }
            .sheet(isPresented: $zeigeEingabe) { LogEntryView() }
            .sheet(item: $shakeDetail) { wrap in ShakeDetailView(shake: wrap.shake) }
        }
    }

    // MARK: - Inhalt

    private func inhalt(_ sitzung: PlanSitzung) -> some View {
        List {
            if !sitzung.plan.warnungen.isEmpty {
                Section("Hinweise") {
                    ForEach(sitzung.plan.warnungen) { warnung in
                        warnungZeile(warnung)
                    }
                }
            }
            Section("Profil: \(sitzung.profilName)") {
                if sitzung.plan.slots.isEmpty {
                    Text("Für den Rest des Tages sind keine Slots mehr offen.")
                        .foregroundStyle(.secondary)
                }
                ForEach(sitzung.plan.slots) { slot in
                    slotZeile(slot)
                }
            }
        }
    }

    private func warnungZeile(_ w: Warnung) -> some View {
        let farbe: Color = (w.art == .zielUnrealistisch || w.art == .keineKandidaten) ? Theme.fehler : Theme.warnung
        return Label {
            Text(w.text).font(.subheadline)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(farbe)
        }
    }

    private func slotZeile(_ slot: GeplanterSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(slot.uhrzeit.anzeige).font(.headline)
                Text("· \(slot.tageszeit.anzeige)").font(.subheadline).foregroundStyle(.secondary)
                if slot.istShakeSlot {
                    Image(systemName: "cup.and.saucer.fill").foregroundStyle(Theme.akzent)
                }
                Spacer()
                Text(Format.kcal(slot.kcalBudget)).font(.subheadline).foregroundStyle(.secondary)
            }

            if let v = slot.vorschlag {
                vorschlagInhalt(slot: slot, vorschlag: v)
            } else {
                Text("Kein Vorschlag möglich.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func vorschlagInhalt(slot: GeplanterSlot, vorschlag v: Vorschlag) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(v.name).font(.body.bold())
                Text(mengeText(v)).font(.caption).foregroundStyle(.secondary)
                Text(makroText(v.makros)).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.kcal(v.kcal)).font(.subheadline.bold())
        }

        if v.istShake, let shake = v.shake {
            Button { shakeDetail = ShakeDetailWrap(shake: shake) } label: {
                Label("Shake ansehen", systemImage: "list.bullet").font(.caption)
            }
            .buttonStyle(.borderless)
        }

        HStack {
            if angenommen.contains(slot.id) {
                Label("Angenommen", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.akzent).font(.caption)
            } else {
                Button { annehmen(slot) } label: { Text("Annehmen") }
                    .buttonStyle(.borderedProminent)
                Button { ablehnen(slot) } label: { Text("Ablehnen") }
                    .buttonStyle(.bordered)
            }
            Spacer()
            Button { eintragen(v) } label: { Label("Eintragen", systemImage: "plus") }
                .buttonStyle(.bordered)
        }
        .font(.subheadline)
    }

    private func mengeText(_ v: Vorschlag) -> String {
        if v.istShake { return "Shake" }
        if let p = v.portionen, let name = v.portionsName {
            return "\(Format.dezimal(p, maxNachkomma: 1)) × \(name)"
        }
        if let g = v.menge_g { return Format.gramm(g) }
        return ""
    }

    private func makroText(_ m: Makros) -> String {
        "P \(Format.gramm(m.protein)) · F \(Format.gramm(m.fett)) · KH \(Format.gramm(m.kohlenhydrate))"
    }

    // MARK: - Aktionen

    private func neuPlanen() {
        guard let settings else { return }
        angenommen.removeAll()
        sitzung = PlanBerechnung.sitzung(context: context, settings: settings)
    }

    private func annehmen(_ slot: GeplanterSlot) {
        guard let sitzung else { return }
        PlanBerechnung.annehmen(slotId: slot.id, sitzung: sitzung, context: context)
        angenommen.insert(slot.id)
    }

    private func ablehnen(_ slot: GeplanterSlot) {
        guard var aktuelle = sitzung else { return }
        PlanBerechnung.ablehnen(slotId: slot.id, sitzung: &aktuelle, context: context)
        sitzung = aktuelle
        angenommen.remove(slot.id)
    }

    private func eintragen(_ v: Vorschlag) {
        if v.istShake, let shake = v.shake {
            let log = LogEntry(
                zeitstempel: Date(),
                foodName: "Shake",
                netto_g: shake.komponenten.reduce(0) { $0 + $1.menge_g },
                kcal: shake.gesamtKcal,
                protein: shake.gesamtMakros.protein,
                fett: shake.gesamtMakros.fett,
                kohlenhydrate: shake.gesamtMakros.kohlenhydrate,
                tageszeit: Tageszeit.ausUhrzeit(Uhrzeit.aus(date: Date())))
            context.insert(log)
            try? context.save()
            neuPlanen()
        } else {
            zustand.eingabeVorbelegtFoodID = v.foodId
            zeigeEingabe = true
        }
    }
}

/// Hilfs-Wrapper, damit `ShakeVorschlag` per `.sheet(item:)` präsentiert werden kann.
private struct ShakeDetailWrap: Identifiable {
    let id = UUID()
    let shake: ShakeVorschlag
}
