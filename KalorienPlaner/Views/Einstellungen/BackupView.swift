import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export/Import der kompletten Datenbank als JSON. Wichtig vor SideStore-Neuinstallation.
struct BackupView: View {
    @Environment(\.modelContext) private var context

    @State private var exportURL: URL?
    @State private var zeigeImport = false
    @State private var meldung: String?
    @State private var zeigeMeldung = false

    var body: some View {
        Form {
            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Backup teilen / sichern", systemImage: "square.and.arrow.up")
                    }
                } else {
                    ProgressView()
                }
                Button { exportNeuErzeugen() } label: {
                    Label("Backup neu erstellen", systemImage: "arrow.clockwise")
                }
            } header: {
                Text("Exportieren")
            } footer: {
                Text("Erstellt eine JSON-Datei mit allen Lebensmitteln, Behältern, Profilen, Einträgen und Einstellungen. Sichere sie z. B. in iCloud Drive.")
            }

            Section {
                Button(role: .destructive) { zeigeImport = true } label: {
                    Label("Backup importieren (ersetzt alle Daten)", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Wiederherstellen")
            } footer: {
                Text("Achtung: Der Import ersetzt den kompletten aktuellen Datenbestand.")
            }
        }
        .navigationTitle("Datensicherung")
        .onAppear { if exportURL == nil { exportNeuErzeugen() } }
        .fileImporter(isPresented: $zeigeImport, allowedContentTypes: [.json]) { result in
            importieren(result)
        }
        .alert("Datensicherung", isPresented: $zeigeMeldung) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(meldung ?? "")
        }
    }

    private func exportNeuErzeugen() {
        do {
            exportURL = try Backup.exportDatei(context: context)
        } catch {
            meldung = "Export fehlgeschlagen: \(error.localizedDescription)"
            zeigeMeldung = true
        }
    }

    private func importieren(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                try Backup.importieren(data: data, context: context)
                meldung = "Import erfolgreich abgeschlossen."
                exportNeuErzeugen()
            } catch {
                meldung = "Import fehlgeschlagen: \(error.localizedDescription)"
            }
        case .failure(let error):
            meldung = "Datei konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
        zeigeMeldung = true
    }
}
