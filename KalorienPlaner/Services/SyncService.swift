import Foundation
import SwiftData

/// Optionaler Cloud-Sync gegen den selbst-gehosteten KalorienPlaner-Sync-Server.
///
/// Nutzt bewusst das bestehende JSON-Backup-Format (`Backup.exportieren`/`importieren`):
/// - **Hochladen** = aktuelles Backup per `PUT /v1/backup` senden.
/// - **Herunterladen** = `GET /v1/backup` und damit die lokale DB ersetzen (Last-Write-Wins).
///
/// Wichtig: Der Sync ist optional. Ist nichts konfiguriert, wird er nie aufgerufen und die App
/// funktioniert unverändert komplett offline.
enum SyncService {

    enum SyncFehler: LocalizedError {
        case nichtKonfiguriert
        case ungueltigeURL
        case nichtAutorisiert
        case keineDatenAufServer
        case serverFehler(Int)
        case keineAntwort

        var errorDescription: String? {
            switch self {
            case .nichtKonfiguriert: return "Server-URL und API-Schlüssel müssen gesetzt sein."
            case .ungueltigeURL: return "Die Server-URL ist ungültig (z. B. https://sync.deinedomain.de)."
            case .nichtAutorisiert: return "Nicht autorisiert – stimmt der API-Schlüssel?"
            case .keineDatenAufServer: return "Auf dem Server liegt noch kein Backup. Lade zuerst von einem Gerät hoch."
            case .serverFehler(let code): return "Server-Fehler (HTTP \(code))."
            case .keineAntwort: return "Keine Antwort vom Server."
            }
        }
    }

    /// Lädt den aktuellen Stand hoch. Gibt die neue Server-Version zurück.
    @discardableResult
    static func hochladen(context: ModelContext, settings: AppSettings) async throws -> Int {
        var request = try anfrage(serverURL: settings.syncServerURL, apiKey: settings.syncAPIKey, methode: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Backup.exportieren(context: context)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncFehler.keineAntwort }
        try pruefeStatus(http)

        struct Antwort: Decodable { var version: Int }
        let version = (try? JSONDecoder().decode(Antwort.self, from: data))?.version ?? settings.syncVersion + 1
        settings.syncVersion = version
        settings.syncZuletzt = Date()
        try? context.save()
        return version
    }

    /// Holt den Server-Stand und ersetzt damit die lokale Datenbank.
    ///
    /// Achtung: `Backup.importieren` löscht und ersetzt ALLE lokalen Daten – inkl. der
    /// `AppSettings`. Deshalb werden URL/Schlüssel vorher gesichert und danach auf die
    /// neu erzeugte Settings-Instanz zurückgeschrieben (das Geheimnis bleibt so lokal).
    static func herunterladen(context: ModelContext, settings: AppSettings) async throws {
        let serverURL = settings.syncServerURL
        let apiKey = settings.syncAPIKey

        let request = try anfrage(serverURL: serverURL, apiKey: apiKey, methode: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncFehler.keineAntwort }
        if http.statusCode == 404 { throw SyncFehler.keineDatenAufServer }
        try pruefeStatus(http)

        // Ersetzt die komplette lokale DB (die übergebene `settings`-Instanz wird dabei verworfen).
        try Backup.importieren(data: data, context: context)

        // Frische Settings holen und die Sync-Konfiguration wiederherstellen.
        let neueSettings = SeedImporter.ersteEinrichtung(context: context)
        neueSettings.syncServerURL = serverURL
        neueSettings.syncAPIKey = apiKey
        if let v = http.value(forHTTPHeaderField: "X-Sync-Version"), let iv = Int(v) {
            neueSettings.syncVersion = iv
        }
        neueSettings.syncZuletzt = Date()
        try? context.save()
    }

    // MARK: - Helfer

    private static func anfrage(serverURL: String, apiKey: String, methode: String) throws -> URLRequest {
        let basis = serverURL.trimmingCharacters(in: .whitespaces)
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !basis.isEmpty, !key.isEmpty else { throw SyncFehler.nichtKonfiguriert }

        let ohneSlash = basis.hasSuffix("/") ? String(basis.dropLast()) : basis
        guard let url = URL(string: ohneSlash + "/v1/backup"), url.scheme != nil else {
            throw SyncFehler.ungueltigeURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = methode
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        return request
    }

    private static func pruefeStatus(_ http: HTTPURLResponse) throws {
        switch http.statusCode {
        case 200...299: return
        case 401, 403: throw SyncFehler.nichtAutorisiert
        case 404: throw SyncFehler.keineDatenAufServer
        default: throw SyncFehler.serverFehler(http.statusCode)
        }
    }
}
