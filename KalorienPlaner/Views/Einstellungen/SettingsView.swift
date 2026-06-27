import SwiftUI
import SwiftData

/// Einstellungen: Ziele, Planungs-Parameter, Behälter, Benachrichtigungen und Datensicherung.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsListe: [AppSettings]
    @Query private var profile: [RoutineProfil]

    @State private var zeigeZiele = false

    private var aktivesProfil: RoutineProfil? { profile.first { $0.aktiv } ?? profile.first }

    var body: some View {
        NavigationStack {
            if let settings = settingsListe.first {
                inhalt(settings)
            } else {
                ProgressView().navigationTitle("Einstellungen")
            }
        }
    }

    private func inhalt(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings
        return Form {
            Section("Ziele") {
                Button { zeigeZiele = true } label: {
                    LabeledContent("Kalorien & Makros & Wasser") {
                        Text(Format.kcal(settings.kcalZiel)).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Planung") {
                Picker("Vorliebe", selection: $settings.planungsVorliebe) {
                    ForEach(PlanungsVorliebe.allCases) { Text($0.anzeige).tag($0) }
                }
                Stepper("Shakes pro Tag: \(settings.shakeProTag)", value: $settings.shakeProTag, in: 0...5)
                HStack {
                    Text("Mindest-kcal je Shake")
                    Spacer()
                    TextField("kcal", value: $settings.shakeMindestKcal, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                }
                VStack(alignment: .leading) {
                    Text("Max. Portion je Slot: \(Format.dezimal(settings.maxSlotFaktor, maxNachkomma: 1))× Durchschnitt")
                        .font(.subheadline)
                    Slider(value: $settings.maxSlotFaktor, in: 1...4, step: 0.1)
                }
            }

            Section("Verwaltung") {
                NavigationLink { BehaelterListView() } label: { Label("Behälter", systemImage: "takeoutbag.and.cup.and.straw") }
            }

            Section("Erinnerungen") {
                Toggle("Slot-Erinnerungen", isOn: $settings.benachrichtigungenAktiv)
                    .onChange(of: settings.benachrichtigungenAktiv) { _, an in
                        slotErinnerungenUmschalten(an: an, settings: settings)
                    }
                Toggle("Wasser-Erinnerungen", isOn: $settings.wasserErinnerungAktiv)
                    .onChange(of: settings.wasserErinnerungAktiv) { _, an in
                        wasserErinnerungenUmschalten(an: an, settings: settings)
                    }
            }

            Section("Daten") {
                NavigationLink { BackupView() } label: { Label("Datensicherung (Export/Import)", systemImage: "externaldrive") }
                NavigationLink { SyncView() } label: { Label("Cloud-Sync (optional)", systemImage: "arrow.triangle.2.circlepath") }
            }

            Section {
                LabeledContent("Version", value: appVersion)
            } footer: {
                Text("Läuft offline auf deinem iPhone. Cloud-Sync ist optional und selbst gehostet – kein Login, kein Tracking.")
            }
        }
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $zeigeZiele) { ZieleBearbeitenView(settings: settings) }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return v
    }

    // MARK: - Erinnerungen

    private func slotErinnerungenUmschalten(an: Bool, settings: AppSettings) {
        if an {
            Task {
                let erlaubt = await NotificationManager.shared.berechtigungAnfragen()
                if erlaubt, let profil = aktivesProfil {
                    NotificationManager.shared.slotErinnerungenPlanen(profil: profil)
                } else {
                    settings.benachrichtigungenAktiv = false
                }
                try? context.save()
            }
        } else {
            NotificationManager.shared.slotErinnerungenEntfernen()
            try? context.save()
        }
    }

    private func wasserErinnerungenUmschalten(an: Bool, settings: AppSettings) {
        if an {
            Task {
                let erlaubt = await NotificationManager.shared.berechtigungAnfragen()
                if erlaubt {
                    NotificationManager.shared.wasserErinnerungenPlanen()
                } else {
                    settings.wasserErinnerungAktiv = false
                }
                try? context.save()
            }
        } else {
            NotificationManager.shared.wasserErinnerungenEntfernen()
            try? context.save()
        }
    }
}
