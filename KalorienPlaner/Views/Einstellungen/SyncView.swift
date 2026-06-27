import SwiftUI
import SwiftData

/// Optionaler Cloud-Sync gegen den selbst-gehosteten Server (siehe `server/`).
/// Komplett opt-in: ohne Konfiguration bleibt die App rein offline.
struct SyncView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsListe: [AppSettings]

    @State private var laeuft = false
    @State private var meldung: String?
    @State private var zeigeMeldung = false
    @State private var zeigeDownloadWarnung = false

    var body: some View {
        Group {
            if let settings = settingsListe.first {
                inhalt(settings)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Cloud-Sync")
        .alert("Cloud-Sync", isPresented: $zeigeMeldung) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(meldung ?? "")
        }
    }

    private func inhalt(_ settings: AppSettings) -> some View {
        @Bindable var settings = settings
        return Form {
            Section {
                TextField("https://sync.deinedomain.de", text: $settings.syncServerURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("API-Schlüssel", text: $settings.syncAPIKey)
                Button("Verbindung speichern") { try? context.save() }
            } header: {
                Text("Server")
            } footer: {
                Text("Nur HTTPS. Eigener Server – Einrichtung siehe server/README.md. Der API-Schlüssel bleibt nur lokal und wird nicht ins Backup geschrieben.")
            }

            Section("Aktionen") {
                Button { hochladen(settings) } label: {
                    Label("Jetzt hochladen", systemImage: "arrow.up.circle")
                }
                .disabled(!settings.syncKonfiguriert || laeuft)

                Button(role: .destructive) { zeigeDownloadWarnung = true } label: {
                    Label("Herunterladen (überschreibt lokal)", systemImage: "arrow.down.circle")
                }
                .disabled(!settings.syncKonfiguriert || laeuft)
            }

            Section("Status") {
                LabeledContent("Server-Version", value: "\(settings.syncVersion)")
                LabeledContent("Zuletzt") { Text(zuletztText(settings.syncZuletzt)) }
                if laeuft {
                    HStack { ProgressView(); Text("Synchronisiere …").foregroundStyle(.secondary) }
                }
            }
        }
        .confirmationDialog("Lokale Daten ersetzen?", isPresented: $zeigeDownloadWarnung, titleVisibility: .visible) {
            Button("Herunterladen & ersetzen", role: .destructive) { herunterladen(settings) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle aktuellen lokalen Daten werden durch das Backup vom Server überschrieben.")
        }
    }

    private func zuletztText(_ datum: Date?) -> String {
        guard let datum else { return "–" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: datum)
    }

    // MARK: - Aktionen

    private func hochladen(_ settings: AppSettings) {
        laeuft = true
        Task {
            do {
                let version = try await SyncService.hochladen(context: context, settings: settings)
                meldung = "Hochgeladen. Server-Version: \(version)."
            } catch {
                meldung = error.localizedDescription
            }
            laeuft = false
            zeigeMeldung = true
        }
    }

    private func herunterladen(_ settings: AppSettings) {
        laeuft = true
        Task {
            do {
                try await SyncService.herunterladen(context: context, settings: settings)
                meldung = "Daten vom Server übernommen."
            } catch {
                meldung = error.localizedDescription
            }
            laeuft = false
            zeigeMeldung = true
        }
    }
}
